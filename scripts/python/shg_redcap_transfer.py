
"""
SHG Diabetes Triage Transfer
First draft: read-only reconciliation.

TEST PROJECTS ONLY
Triage:   1091
Registry: 1090

This script never imports, updates or deletes REDCap records.

Outputs:
    reconciliation_PRIVATE.csv
    summary.yml

All outputs remain in the private SHG workspace.
"""

import argparse
import csv
import json
import re
from collections import Counter, defaultdict
from datetime import datetime, timezone
from pathlib import Path

import requests


API_URL = "https://caribdata.org/redcap/api/"

TRIAGE_PROJECT = "1091"
REGISTRY_PROJECT = "1090"

SOURCE_ID = "internal_redcap_id"

PROCESS_FIELDS = {
    "triage_decision",
    "triage_decision_other",
    "lastcontact_date",
    "blood_test_app_date",
    "clinic",
}

IDENTITY_FIELDS = (
    "first_name",
    "family_name",
    "date_of_birth",
    "sex",
)


# ============================================================
# 1. Identifier and identity helpers
# ============================================================

def normalise(value):
    """Normalise patient identifiers for comparison."""

    return re.sub(
        r"\s+", "", str(value or "")
    ).casefold()


def normalise_name(value):
    """Normalise demographic values for comparison."""

    return " ".join(
        str(value or "").casefold().split()
    )


def identity(record):
    """Return the demographic identity tuple."""

    return tuple(
        normalise_name(record.get(field))
        for field in IDENTITY_FIELDS
    )


def identity_complete(record):
    """Check that the demographic identity is complete."""

    return all(identity(record))


# ============================================================
# 2. REDCap API helpers
# ============================================================

def read_token(path):
    """Read an API token from the private configuration folder."""

    if not path.is_file():
        raise RuntimeError(
            "Token file not found: " + str(path)
        )

    token = path.read_text(
        encoding="utf-8-sig"
    ).strip()

    if not token or "\n" in token:
        raise RuntimeError(
            "Token file must contain one API token."
        )

    return token


def api_request(token, parameters):
    """Make a REDCap API request."""

    payload = {
        "token": token,
        "format": "json",
        "returnFormat": "json",
        **parameters,
    }

    response = requests.post(
        API_URL,
        data=payload,
        timeout=(15, 180),
    )

    response.raise_for_status()

    result = response.json()

    if isinstance(result, dict) and "error" in result:
        raise RuntimeError(
            "REDCap API error: " + str(result["error"])
        )

    return result


def get_project_id(token):
    """Retrieve and verify the REDCap project ID."""

    result = api_request(
        token,
        {"content": "project"},
    )

    return str(result["project_id"])


def export_records(token):
    """Export REDCap records using raw field values."""

    return api_request(
        token,
        {
            "content": "record",
            "type": "flat",
            "rawOrLabel": "raw",
            "rawOrLabelHeaders": "raw",
        },
    )


def export_metadata(token):
    """Export the REDCap project data dictionary."""

    return api_request(
        token,
        {"content": "metadata"},
    )


# ============================================================
# 3. Patient identity and reconciliation
# ============================================================

def get_patient_identity(record):
    """Return the available patient identifiers."""

    return {
        "psource_id": normalise(
            record.get("psource_id")
        ),
        "emis_id": normalise(
            record.get("emis_id")
        ),
        "demographics": identity(record),
    }


def reconcile(triage, registry):
    """
    Identify eligible patients and possible registry matches.

    Ambiguous records are excluded from automatic transfer.

    Eligibility:
        triage_decision == 1
        triage_review_complete == 2

    Matching:
        psource_id
        emis_id
        demographic identity

    Duplicate identifiers in triage are excluded pending review.
    """

    # Identify duplicate PatientSource identifiers in triage.

    triage_ps = Counter(
        normalise(r.get("psource_id"))
        for r in triage
        if normalise(r.get("psource_id"))
    )

    # Identify duplicate EMIS identifiers in triage.

    triage_emis = Counter(
        normalise(r.get("emis_id"))
        for r in triage
        if normalise(r.get("emis_id"))
    )

    # Build destination registry lookup tables.

    registry_ps = defaultdict(set)
    registry_emis = defaultdict(set)
    registry_demographics = defaultdict(set)

    for record in registry:

        rid = str(
            record.get(SOURCE_ID, "")
        ).strip()

        if not rid:
            raise RuntimeError(
                "Registry record has no internal ID."
            )

        ps = normalise(
            record.get("psource_id")
        )

        em = normalise(
            record.get("emis_id")
        )

        if ps:
            registry_ps[ps].add(rid)

        if em:
            registry_emis[em].add(rid)

        if identity_complete(record):
            registry_demographics[
                identity(record)
            ].add(rid)

    # Classify every triage record.

    results = []

    for record in triage:

        source_id = str(
            record.get(SOURCE_ID, "")
        ).strip()

        ps = normalise(
            record.get("psource_id")
        )

        em = normalise(
            record.get("emis_id")
        )

        decision = str(
            record.get("triage_decision", "")
        ).strip()

        completion = str(
            record.get("triage_review_complete", "")
        ).strip()

        # Both eligibility criteria must be satisfied.

        if decision != "1" or completion != "2":

            status = "not_eligible"

        elif not ps:

            status = "missing_psource_id_review"

        elif triage_ps[ps] > 1:

            status = "duplicate_psource_id_review"

        elif not em:

            status = "missing_emis_id_review"

        elif triage_emis[em] > 1:

            status = "duplicate_emis_id_review"

        else:

            matches = set()

            matches.update(
                registry_ps.get(ps, set())
            )

            matches.update(
                registry_emis.get(em, set())
            )

            if identity_complete(record):
                matches.update(
                    registry_demographics.get(
                        identity(record), set()
                    )
                )

            if len(matches) > 1:

                status = "conflicting_matches_review"

            elif len(matches) == 1:

                status = "already_registered_or_review"

            elif not identity_complete(record):

                status = "incomplete_identity_review"

            else:

                status = "new_candidate"

        results.append(
            {
                "source_id": source_id,
                "psource_id": record.get(
                    "psource_id", ""
                ),
                "emis_id": record.get(
                    "emis_id", ""
                ),
                "status": status,
            }
        )

    return results


# ============================================================
# 4. Main read-only preview
# ============================================================

def main():

    parser = argparse.ArgumentParser()

    parser.add_argument(
        "--private",
        required=True,
    )

    args = parser.parse_args()

    private = Path(
        args.private
    ).resolve()

    config = private / "config"

    # --------------------------------------------------------
    # Read the test-project credentials.
    # --------------------------------------------------------

    triage_token = read_token(
        config / "triage_token.txt"
    )

    registry_token = read_token(
        config / "registry_token.txt"
    )

    # --------------------------------------------------------
    # Verify both project IDs before accessing patient records.
    # --------------------------------------------------------

    tid = get_project_id(
        triage_token
    )

    rid = get_project_id(
        registry_token
    )

    if tid != TRIAGE_PROJECT or rid != REGISTRY_PROJECT:

        raise RuntimeError(
            "TEST PROJECT LOCK: expected "
            "triage 1091 and registry 1090; "
            f"received {tid} and {rid}."
        )

    print(
        "REDCap test projects verified."
    )

    # --------------------------------------------------------
    # Export project metadata.
    # --------------------------------------------------------

    triage_metadata = export_metadata(
        triage_token
    )

    registry_metadata = export_metadata(
        registry_token
    )

    triage_fields = {
        r["field_name"]
        for r in triage_metadata
    }

    registry_fields = {
        r["field_name"]
        for r in registry_metadata
    }

    # Every triage field must either exist in the registry
    # or be one of the five agreed process-only fields.

    unexpected = (
        triage_fields
        - registry_fields
        - PROCESS_FIELDS
    )

    if unexpected:

        raise RuntimeError(
            "Unexpected triage-only fields: "
            + ", ".join(
                sorted(unexpected)
            )
        )

    # The triage internal ID must not be copied.
    # REDCap assigns the destination registry ID.

    transfer_fields = sorted(
        (
            triage_fields
            & registry_fields
        ) - {SOURCE_ID}
    )

    # --------------------------------------------------------
    # Export records from both test projects.
    # --------------------------------------------------------

    triage = export_records(
        triage_token
    )

    registry = export_records(
        registry_token
    )

    if not triage:

        raise RuntimeError(
            "Triage export returned no records."
        )

    # REDCap instrument-completion fields may not appear
    # in the standard data dictionary.
    # Confirm that the required completion field was exported.

    if any(
        "triage_review_complete" not in r
        for r in triage
    ):

        raise RuntimeError(
            "Triage completion field missing "
            "from API export."
        )

    # --------------------------------------------------------
    # Reconcile triage against the destination registry.
    # --------------------------------------------------------

    results = reconcile(
        triage,
        registry,
    )

    counts = Counter(
        r["status"]
        for r in results
    )

    # Calculate the number satisfying both eligibility rules.

    eligible_count = sum(
        1
        for r in triage
        if (
            str(
                r.get("triage_decision", "")
            ).strip() == "1"
            and
            str(
                r.get("triage_review_complete", "")
            ).strip() == "2"
        )
    )

    # --------------------------------------------------------
    # Create a private output folder for this preview.
    # --------------------------------------------------------

    now = datetime.now(
        timezone.utc
    )

    stamp = now.strftime(
        "%Y%m%dT%H%M%SZ"
    )

    folder_name = (
        "preview-"
        + now.strftime("%Y-%m-%d_%H%M%S")
        + "-UTC"
    )

    output = (
        private
        / "work"
        / "triage-transfer"
        / "previews"
        / folder_name
    )

    output.mkdir(
        parents=True,
        exist_ok=False,
    )

    # --------------------------------------------------------
    # Write the private record-level reconciliation.
    # --------------------------------------------------------

    review_file = (
        output
        / "reconciliation_PRIVATE.csv"
    )

    with review_file.open(
        "w",
        newline="",
        encoding="utf-8-sig",
    ) as f:

        writer = csv.DictWriter(
            f,
            fieldnames=[
                "source_id",
                "psource_id",
                "emis_id",
                "status",
            ],
        )

        writer.writeheader()

        writer.writerows(
            results
        )

    # --------------------------------------------------------
    # Write the human-readable YAML summary.
    # --------------------------------------------------------

    # JSON-quoted strings are valid YAML 1.2 scalars.
    # This avoids introducing a PyYAML dependency for
    # a small, fixed metadata document.

    summary_file = (
        output
        / "summary.yml"
    )

    yaml_lines = [
        "# SHG diabetes triage transfer",
        "",
        "run:",
        f"  timestamp_utc: {json.dumps(stamp)}",
        "  environment: test",
        "  operation: preview",
        "  read_only: true",
        "",
        "projects:",
        f"  triage: {json.dumps(tid)}",
        f"  registry: {json.dumps(rid)}",
        "",
        "records:",
        f"  triage_total: {len(triage)}",
        f"  registry_export_rows: {len(registry)}",
        f"  eligible: {eligible_count}",
        f"  not_eligible: {counts.get('not_eligible', 0)}",
        f"  new_candidates: {counts.get('new_candidate', 0)}",
        "",
        "decisions:",
    ]

    # Include every matching and eligibility classification,
    # including categories with zero records where applicable.

    for status, count in sorted(
        counts.items()
    ):

        yaml_lines.append(
            f"  {status}: {count}"
        )

    # Document the fields shared between the two projects.

    yaml_lines.extend([
        "",
        "transfer_fields:",
    ])

    for field in transfer_fields:

        yaml_lines.append(
            f"  - {json.dumps(field)}"
        )

    # Document the private worklist location and
    # explicitly record that no REDCap records were modified.

    yaml_lines.extend([
        "",
        "files:",
        f"  reconciliation: {json.dumps(str(review_file))}",
        "",
        "verification:",
        "  status: preview_only",
        "  redcap_records_modified: false",
        "",
    ])

    summary_file.write_text(
        "\n".join(yaml_lines),
        encoding="utf-8",
    )

    # --------------------------------------------------------
    # Display the operator summary.
    # --------------------------------------------------------

    print()

    print(
        "SHG TRIAGE TRANSFER PREVIEW"
    )

    print(
        "=========================="
    )

    print(
        "Triage records:",
        len(triage),
    )

    print(
        "Registry export rows:",
        len(registry),
    )

    print(
        "Eligible triage records:",
        eligible_count,
    )

    print()

    for status, count in sorted(
        counts.items()
    ):

        print(
            f"{status}: {count}"
        )

    print()

    print(
        "Private results:",
        output,
    )

    print(
        "YAML summary:",
        summary_file,
    )

    print()

    print(
        "READ-ONLY PREVIEW COMPLETE. "
        "No REDCap records were modified."
    )


if __name__ == "__main__":
    main()
