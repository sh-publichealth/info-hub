
"""
SHG diabetes triage to registry: controlled production import.

Uses the existing shg_redcap_transfer.py preview module.
Production projects: triage 1087, registry 1077.

Without --confirm, this program performs read-only validation.
An optional --limit supports a deliberately bounded first run.
"""

import argparse
from collections import defaultdict
from datetime import date, datetime, timezone
import hashlib
import json
from pathlib import Path

import shg_redcap_transfer as preview


TRIAGE_PID = "1087"
REGISTRY_PID = "1077"
CONFIRMATION = "TRANSFER-1087-TO-1077"

EXCLUDE = {
    "internal_redcap_id",
    "triage_decision",
    "triage_decision_other",
    "lastcontact_date",
    "blood_test_app_date",
    "clinic",
}

SUPPORTED = {
    "text", "notes", "radio", "dropdown",
    "yesno", "truefalse",
}

IDENTITY = (
    "psource_id", "emis_id", "first_name",
    "family_name", "date_of_birth", "sex",
)


def required_value(record, field):
    value = str(record.get(field, "") or "").strip()
    if not value:
        raise RuntimeError(
            f"Missing transfer-critical field: {field}"
        )
    return value


def transfer_fields(triage_metadata, registry_metadata):
    triage = {
        r["field_name"]: r for r in triage_metadata
    }
    registry = {
        r["field_name"]: r for r in registry_metadata
    }

    missing = set(triage) - set(registry) - EXCLUDE
    if missing:
        raise RuntimeError(
            "Unmapped triage fields: "
            + ", ".join(sorted(missing))
        )

    fields = []

    for field, source in triage.items():
        if field in EXCLUDE:
            continue

        kind = source["field_type"]

        if kind == "descriptive":
            continue

        if kind not in SUPPORTED:
            raise RuntimeError(
                f"Unsupported field type: {field} ({kind})"
            )

        destination = registry[field]

        for item in (
            "field_type",
            "select_choices_or_calculations",
            "text_validation_type_or_show_slider_number",
        ):
            a = str(source.get(item, "") or "")
            b = str(destination.get(item, "") or "")

            if a != b:
                raise RuntimeError(
                    f"Incompatible field definition: "
                    f"{field}: {item}"
                )

        fields.append(field)

    for field in IDENTITY:
        if field not in fields:
            raise RuntimeError(
                "Identity field cannot be transferred: "
                + field
            )

    if registry.get("date_of_entry", {}).get(
        "form_name"
    ) != "baseline":
        raise RuntimeError(
            "date_of_entry must be a baseline field"
        )

    return fields, registry


def repeating_forms(token, metadata):
    settings = preview.api_request(
        token, {"content": "repeatingFormsEvents"}
    )

    if not isinstance(settings, list):
        raise RuntimeError(
            "Repeating-instrument settings unavailable"
        )

    known = {
        field["form_name"] for field in metadata.values()
    }

    result = set()

    for setting in settings:
        form = str(
            setting.get("form_name") or ""
        ).strip()

        event = str(
            setting.get("event_name") or ""
        ).strip()

        if not form or event:
            raise RuntimeError(
                "Repeating events or longitudinal settings "
                "require explicit mapping"
            )

        if form not in known:
            raise RuntimeError(
                "Unknown repeating instrument: " + form
            )

        result.add(form)

    if "baseline" in result:
        raise RuntimeError(
            "Baseline must not be a repeating instrument"
        )

    return result


def rows_for_patient(
    source, record_id, fields, metadata, repeating
):
    """Build baseline and first-instance repeating rows."""

    base = {
        "internal_redcap_id": str(record_id),
        "date_of_entry": date.today().isoformat(),
    }

    repeated = defaultdict(dict)

    for field in fields:
        value = source.get(field, "")

        if value is None or str(value) == "":
            continue

        form = metadata[field]["form_name"]

        if form in repeating:
            repeated[form][field] = str(value)
        else:
            base[field] = str(value)

    required_value(base, "psource_id")
    required_value(base, "emis_id")

    rows = [base]

    for form, values in sorted(repeated.items()):
        rows.append({
            "internal_redcap_id": str(record_id),
            "redcap_repeat_instrument": form,
            "redcap_repeat_instance": "1",
            **values,
        })

    return rows


def find_patient(rows, source):
    """Find the new ID using both shared identifiers."""

    ps = preview.normalise(
        source.get("psource_id")
    )
    em = preview.normalise(
        source.get("emis_id")
    )

    matches = {
        str(r.get("internal_redcap_id", "")).strip()
        for r in rows
        if ps and preview.normalise(
            r.get("psource_id")
        ) == ps
    }

    if len(matches) != 1:
        raise RuntimeError(
            "No unique destination PatientSource match"
        )

    rid = next(iter(matches))

    same_record = [
        r for r in rows
        if str(
            r.get("internal_redcap_id", "")
        ).strip() == rid
    ]

    if not any(
        preview.normalise(
            r.get("emis_id")
        ) == em
        for r in same_record
    ):
        raise RuntimeError(
            "Destination EMIS ID does not match"
        )

    return rid


def verify(
    rows, source, rid, fields, metadata, repeating
):
    """Compare every populated imported field."""

    expected = rows_for_patient(
        source, rid, fields, metadata, repeating
    )

    actual = [
        r for r in rows
        if str(
            r.get("internal_redcap_id", "")
        ).strip() == rid
    ]

    for intended in expected:
        form = intended.get(
            "redcap_repeat_instrument", ""
        )

        instance = str(
            intended.get(
                "redcap_repeat_instance", ""
            ) or ""
        )

        matches = [
            r for r in actual
            if str(
                r.get(
                    "redcap_repeat_instrument", ""
                ) or ""
            ) == form
            and str(
                r.get(
                    "redcap_repeat_instance", ""
                ) or ""
            ) == instance
        ]

        if len(matches) != 1:
            raise RuntimeError(
                "Expected exactly one read-back row: "
                + (form or "baseline")
            )

        for field, value in intended.items():
            if field in {
                "redcap_repeat_instrument",
                "redcap_repeat_instance",
            }:
                continue

            observed = str(
                matches[0].get(field, "") or ""
            )

            if observed != str(value):
                raise RuntimeError(
                    "Read-back mismatch: " + field
                )

    return True


def import_rows(token, rows, auto_number=False):
    payload = {
        "content": "record",
        "type": "flat",
        "overwriteBehavior": "normal",
        "data": json.dumps(
            rows, ensure_ascii=False
        ),
        "returnContent": "count",
    }

    if auto_number:
        payload["forceAutoNumber"] = "true"

    return preview.api_request(token, payload)


def persist(
    path, state, source_id,
    registry_id=None, error=None
):
    receipt = {
        "state": state,
        "source_id": source_id,
        "registry_id": registry_id,
        "updated_utc": datetime.now(
            timezone.utc
        ).isoformat(),
    }

    if error:
        receipt["error"] = str(error)

    path.write_text(
        json.dumps(receipt, indent=2),
        encoding="utf-8",
    )


def main():
    parser = argparse.ArgumentParser()

    parser.add_argument(
        "--private", required=True
    )

    parser.add_argument(
        "--limit", type=int
    )

    parser.add_argument(
        "--confirm", default=""
    )

    args = parser.parse_args()

    if args.limit is not None and args.limit < 1:
        raise RuntimeError(
            "Import limit must be a positive integer"
        )

    if args.confirm and args.confirm != CONFIRMATION:
        raise RuntimeError(
            "Incorrect transfer confirmation"
        )

    private = Path(args.private).resolve()

    if not private.is_dir():
        raise RuntimeError(
            "Private workspace does not exist"
        )

    triage_token = preview.read_token(
        private / "config" / "triage_token_live.txt"
    )

    registry_token = preview.read_token(
        private / "config" / "registry_token_live.txt"
    )

    # Confirm actual project identity and settings.

    if preview.get_project_id(
        triage_token
    ) != TRIAGE_PID:
        raise RuntimeError(
            "Incorrect triage project; expected 1087"
        )

    project = preview.api_request(
        registry_token, {"content": "project"}
    )

    if str(
        project.get("project_id")
    ) != REGISTRY_PID:
        raise RuntimeError(
            "Incorrect registry project; expected 1077"
        )

    if str(
        project.get("record_autonumbering_enabled")
    ) not in {"1", "True", "true"}:
        raise RuntimeError(
            "Enable registry automatic record numbering"
        )

    if str(
        project.get("is_longitudinal", "0")
    ) not in {"0", "False", "false"}:
        raise RuntimeError(
            "Longitudinal event mapping is not configured"
        )

    # Read metadata and records.

    source_metadata = preview.export_metadata(
        triage_token
    )

    target_metadata = preview.export_metadata(
        registry_token
    )

    fields, target_map = transfer_fields(
        source_metadata,
        target_metadata,
    )

    repeats = repeating_forms(
        registry_token, target_map
    )

    triage = preview.export_records(
        triage_token
    )

    registry = preview.export_records(
        registry_token
    )

    decisions = preview.reconcile(
        triage, registry
    )

    eligible = {
        d["source_id"]: d["status"]
        for d in decisions
    }

    candidates = sorted(
        (
            r for r in triage
            if eligible.get(
                str(
                    r.get(
                        "internal_redcap_id", ""
                    )
                ).strip()
            ) == "new_candidate"
        ),
        key=lambda r: str(
            r.get(
                "internal_redcap_id", ""
            )
        ).strip(),
    )

    # Validate all candidates before writing.

    for source in candidates:
        for field in IDENTITY:
            required_value(source, field)

        rows_for_patient(
            source,
            "PROPOSED_ID",
            fields,
            target_map,
            repeats,
        )

    print(
        "REDCap projects verified. "
        f"New candidates: {len(candidates)}"
    )

    print(
        f"Repeating instruments: {len(repeats)}"
    )

    if not args.confirm:
        print(
            "READ-ONLY VALIDATION COMPLETE. "
            "No records imported."
        )
        return

    # Persistent private receipts protect against
    # accidentally repeating a partially successful import.

    ledger = (
        private
        / "work"
        / "triage-transfer"
        / "import-receipts"
    )

    ledger.mkdir(
        parents=True, exist_ok=True
    )

    completed = 0

    selected = (
        candidates
        if args.limit is None
        else candidates[:args.limit]
    )

    for source in selected:
        sid = required_value(
            source, "internal_redcap_id"
        )

        receipt = ledger / (
            hashlib.sha256(
                sid.encode("utf-8")
            ).hexdigest() + ".json"
        )

        if receipt.exists():
            raise RuntimeError(
                "Previous import receipt exists. "
                "Review it before repeating this record."
            )

        # Recheck the destination immediately before import.

        current = preview.export_records(
            registry_token
        )

        current_decisions = preview.reconcile(
            triage, current
        )

        status = next(
            d["status"]
            for d in current_decisions
            if d["source_id"] == sid
        )

        if status != "new_candidate":
            raise RuntimeError(
                "Patient match changed before import. "
                "Run preview again."
            )

        baseline = rows_for_patient(
            source,
            "PROPOSED_ID",
            fields,
            target_map,
            repeats,
        )[0]

        persist(
            receipt,
            "baseline_import_started",
            sid,
        )

        rid = None

        try:
            # REDCap allocates its own internal ID.

            import_rows(
                registry_token,
                [baseline],
                auto_number=True,
            )

            after_baseline = preview.export_records(
                registry_token
            )

            rid = find_patient(
                after_baseline, source
            )

            persist(
                receipt,
                "baseline_verified",
                sid,
                rid,
            )

            # Import instance 1 for each repeating form.

            repeat_rows = rows_for_patient(
                source,
                rid,
                fields,
                target_map,
                repeats,
            )[1:]

            if repeat_rows:
                persist(
                    receipt,
                    "repeating_import_started",
                    sid,
                    rid,
                )

                import_rows(
                    registry_token,
                    repeat_rows,
                )

            # Read back and compare every transferred value.

            final = preview.export_records(
                registry_token
            )

            verify(
                final,
                source,
                rid,
                fields,
                target_map,
                repeats,
            )

            persist(
                receipt,
                "verified",
                sid,
                rid,
            )

            completed += 1

            print(
                f"Verified registry enrolment {completed}."
            )

        except Exception as exc:
            persist(
                receipt,
                "requires_manual_reconciliation",
                sid,
                rid,
                str(exc),
            )

            raise RuntimeError(
                "Import stopped. Review the private "
                "receipt before attempting another import."
            ) from exc

    print(
        "Verified new registry records this run: "
        f"{completed}"
    )

    print(
        "No triage records were modified."
    )


if __name__ == "__main__":
    main()
