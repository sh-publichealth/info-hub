
"""SHG triage run controller: reconciliation, optional import and report inputs.

Production projects: triage 1087, registry 1077.
Requires shg_redcap_transfer.py and shg_triage_import.py.
"""

import argparse
import csv
from collections import Counter
from datetime import datetime, timezone
import json
from pathlib import Path
import re
import subprocess
import sys

import shg_redcap_transfer as preview


TRIAGE_PID = "1087"
REGISTRY_PID = "1077"
CONFIRM = "TRANSFER-1087-TO-1077"

# Keep this in the same order as the triage_decision field definition in the
# REDCap data dictionary.  The report intentionally uses labels, never codes.
TRIAGE_DECISIONS = (
    ("1", "Approved for registry"),
    ("2", "Not approved - Deceased"),
    ("3", "Not approved - Permanently emigrated"),
    ("4", "Not approved - Duplicate record"),
    ("5", "Not approved - Record entered in error"),
    ("6", "Not approved - Not clinically eligible"),
    ("7", "Pending - Patient identity unresolved"),
    ("8", "Pending - Vital or residence status unknown"),
    ("9", "Pending - Clinical confirmation"),
    ("10", "Pending - Unable to verify"),
    ("11", "Other"),
)


def patients(rows):
    """Count distinct registry patients, not repeating-form rows."""
    ids = {
        str(r.get("internal_redcap_id", "")).strip()
        for r in rows
    }
    if "" in ids:
        raise RuntimeError("Registry export includes a blank record ID")
    return ids


def counts(rows):
    return Counter(r["status"] for r in rows)


def new_transfer_rows(registry_rows, new_ids, triage_rows):
    """Return one private baseline row for each newly created registry ID."""

    rows = {}
    wanted = {str(value).strip() for value in new_ids}
    source_by_psource = {}

    for source in triage_rows:
        key = preview.normalise(source.get("psource_id"))
        if not key:
            continue
        if key in source_by_psource:
            source_by_psource[key] = None
        else:
            source_by_psource[key] = source

    for record in registry_rows:
        record_id = str(
            record.get("internal_redcap_id", "")
        ).strip()

        if record_id not in wanted:
            continue

        repeat_form = str(
            record.get("redcap_repeat_instrument", "") or ""
        ).strip()

        repeat_instance = str(
            record.get("redcap_repeat_instance", "") or ""
        ).strip()

        # One non-repeating baseline row carries the patient identity.
        if repeat_form or repeat_instance:
            continue

        if record_id in rows:
            raise RuntimeError(
                "More than one baseline row for new registry ID "
                + record_id
            )

        psource_id = str(record.get("psource_id", "") or "").strip()
        source = source_by_psource.get(preview.normalise(psource_id))
        family_name = str(record.get("family_name", "") or "").strip()
        first_name = str(record.get("first_name", "") or "").strip()

        # The registry export is authoritative.  This private-report fallback
        # supports registry exports which suppress name fields, but only where
        # the source PatientSource ID identifies one triage record uniquely.
        if source is not None:
            family_name = family_name or str(
                source.get("family_name", "") or ""
            ).strip()
            first_name = first_name or str(
                source.get("first_name", "") or ""
            ).strip()

        rows[record_id] = {
            "registry_internal_id": record_id,
            "psource_id": psource_id,
            "family_name": family_name,
            "first_name": first_name,
            "date_of_birth": str(
                record.get("date_of_birth", "") or ""
            ).strip(),
        }

    missing = wanted - set(rows)

    if missing:
        raise RuntimeError(
            "Missing baseline row for new registry ID(s): "
            + ", ".join(sorted(missing))
        )

    return [rows[key] for key in sorted(rows)]


def report_breakdown(triage_rows, before_counts, before_ids, after_ids):
    """Return display rows for the private PDF summary table."""

    complete = [
        row for row in triage_rows
        if str(row.get("triage_review_complete", "")).strip() == "2"
    ]
    eligible = [
        row for row in complete
        if str(row.get("triage_decision", "")).strip() == "1"
    ]
    # These are descriptive triage-decision counts, not transfer eligibility.
    # Count every recorded non-approved decision, including decisions entered
    # before the review-complete field was set.  The completed-review rule
    # above remains the sole definition of an eligible transfer candidate.
    decision_counts = Counter(
        str(row.get("triage_decision", "")).strip() or "blank"
        for row in triage_rows
        if str(row.get("triage_decision", "")).strip() != "1"
    )

    rows = [
        ("section", "Triage: origin", ""),
        ("measure", "Triage records", len(triage_rows)),
        ("measure", "Triage: eligible records", len(eligible)),
        (
            "measure",
            "Triage: eligible already transferred or under review",
            before_counts.get("already_registered_or_review", 0),
        ),
        (
            "measure",
            "Triage: eligible new patients",
            before_counts.get("new_candidate", 0),
        ),
        (
            "measure",
            "Triage: records not yet completed",
            len(triage_rows) - len(complete),
        ),
    ]

    for decision, label in TRIAGE_DECISIONS:
        count = decision_counts.pop(decision, 0)
        if not count:
            continue

        if label.startswith("Not approved - "):
            measure = (
                "Triage: not eligible ("
                + label.removeprefix("Not approved - ").lower() + ")"
            )
        elif label.startswith("Pending - "):
            measure = (
                "Triage: pending ("
                + label.removeprefix("Pending - ").lower() + ")"
            )
        else:
            measure = "Triage: " + label.lower()

        rows.append(("measure", measure, count))

    # No recorded decision is a data-quality state rather than a REDCap
    # choice, so state it plainly after the defined choices.
    blank_count = decision_counts.pop("blank", 0)
    if blank_count:
        rows.append((
            "measure",
            "Triage: no triage decision recorded",
            blank_count,
        ))

    # Preserve visibility of an unexpected future code without inventing a
    # clinical label.  This should normally be empty.
    for decision, count in sorted(decision_counts.items()):
        rows.append((
            "measure",
            "Triage: unrecognised decision " + decision,
            count,
        ))

    rows.extend([
        ("section", "Registry: destination", ""),
        ("measure", "Registry: number before transfer", len(before_ids)),
        ("measure", "Registry: number post transfer", len(after_ids)),
    ])

    return rows


def q(value):
    """Quote a YAML string using JSON-compatible double quotes."""
    return json.dumps(str(value), ensure_ascii=False)


def write_outputs(
    run_dir, metrics, before_decisions, after_decisions, new_transfers,
    breakdown,
):
    """Write Stata report inputs, YAML and private reconciliation."""

    with (run_dir / "report_metrics.csv").open(
        "w", encoding="utf-8", newline=""
    ) as stream:
        writer = csv.DictWriter(stream, fieldnames=list(metrics))
        writer.writeheader()
        writer.writerow(metrics)

    lines = [
        "# SHG diabetes triage transfer: private operational summary",
        "run:",
        f"  time_utc: {q(metrics['time_utc'])}",
        f"  environment: {q('production')}",
        f"  operation: {q(metrics['operation'])}",
        f"  status: {q(metrics['run_status'])}",
        "projects:",
        f"  triage: {q(TRIAGE_PID)}",
        f"  registry: {q(REGISTRY_PID)}",
        "population:",
    ]

    for key in (
        "triage_total",
        "eligible",
        "not_eligible",
        "registry_before",
        "registry_after",
        "registry_export_rows_after",
        "new_candidates_before",
        "new_candidates_after",
        "new_registry_patients",
        "verified_imports",
        "identity_review_after",
    ):
        lines.append(f"  {key}: {metrics[key]}")

    lines.append("decisions_before:")

    for label, number in sorted(counts(before_decisions).items()):
        lines.append(f"  {label}: {number}")

    lines.append("decisions_after:")

    for label, number in sorted(counts(after_decisions).items()):
        lines.append(f"  {label}: {number}")

    lines.extend([
        "files:",
        f"  reconciliation: {q((run_dir / 'reconciliation_PRIVATE.csv').as_posix())}",
        f"  new_transfers: {q((run_dir / 'new_transfers_PRIVATE.csv').as_posix())}",
        f"  report_breakdown: {q((run_dir / 'report_breakdown.csv').as_posix())}",
        f"  report_metrics: {q((run_dir / 'report_metrics.csv').as_posix())}",
        f"  pdf: {q((run_dir / 'triage-transfer-report.pdf').as_posix())}",
        "notes:",
        "  - 'Registry counts use distinct internal_redcap_id values, not export rows.'",
        "  - 'already_registered_or_review is not yet a confirmed-identity classification.'",
        "  - 'Onboarding fields may legitimately remain incomplete after transfer.'",
        "",
    ])

    (run_dir / "summary.yml").write_text(
        "\n".join(lines), encoding="utf-8"
    )

    with (run_dir / "reconciliation_PRIVATE.csv").open(
        "w", encoding="utf-8-sig", newline=""
    ) as stream:
        writer = csv.DictWriter(
            stream,
            fieldnames=[
                "source_id",
                "psource_id",
                "emis_id",
                "status_before",
                "status_after",
            ],
        )
        writer.writeheader()

        after = {
            r["source_id"]: r["status"]
            for r in after_decisions
        }

        for item in before_decisions:
            writer.writerow({
                "source_id": item["source_id"],
                "psource_id": item["psource_id"],
                "emis_id": item["emis_id"],
                "status_before": item["status"],
                "status_after": after.get(
                    item["source_id"], "missing_after"
                ),
            })

    with (run_dir / "new_transfers_PRIVATE.csv").open(
        "w", encoding="utf-8-sig", newline=""
    ) as stream:
        writer = csv.DictWriter(
            stream,
            fieldnames=[
                "registry_internal_id",
                "psource_id",
                "family_name",
                "first_name",
                "date_of_birth",
            ],
        )
        writer.writeheader()
        writer.writerows(new_transfers)

    with (run_dir / "report_breakdown.csv").open(
        "w", encoding="utf-8-sig", newline=""
    ) as stream:
        writer = csv.writer(stream)
        writer.writerow(["row_type", "measure", "count"])
        writer.writerows(breakdown)


def main():
    parser = argparse.ArgumentParser()

    parser.add_argument("--private", required=True)
    parser.add_argument(
        "--mode",
        choices=("preview", "transfer"),
        default="preview",
    )
    parser.add_argument("--limit", type=int)
    parser.add_argument("--confirm", default="")

    args = parser.parse_args()

    if args.mode == "transfer" and args.confirm != CONFIRM:
        parser.error(
            "Transfer requires --confirm TRANSFER-1087-TO-1077"
        )

    if args.limit is not None and args.limit < 1:
        parser.error("Transfer limit must be a positive integer")

    if args.mode == "preview" and args.limit is not None:
        parser.error("Preview does not accept an import limit")

    if args.mode == "preview" and args.confirm:
        parser.error("Preview does not accept import confirmation")

    private = Path(args.private).resolve(strict=True)

    root = private / "work" / "triage-transfer"
    root.mkdir(parents=True, exist_ok=True)

    run_dir = root / "runs" / (
        f"{args.mode}-"
        f"{datetime.now(timezone.utc):%Y-%m-%d_%H%M%S_%f}-UTC"
    )

    run_dir.mkdir(parents=True, exist_ok=False)

    pointer = root / "latest_run_path.txt"
    pointer.unlink(missing_ok=True)

    # Verify actual project IDs before reading patient records.

    triage_token = preview.read_token(
        private / "config" / "triage_token_live.txt"
    )

    registry_token = preview.read_token(
        private / "config" / "registry_token_live.txt"
    )

    if preview.get_project_id(triage_token) != TRIAGE_PID:
        raise RuntimeError(
            "Wrong triage project; expected project 1087"
        )

    if preview.get_project_id(registry_token) != REGISTRY_PID:
        raise RuntimeError(
            "Wrong registry project; expected project 1077"
        )

    # Reconcile the database state before this run.

    triage = preview.export_records(triage_token)
    before_rows = preview.export_records(registry_token)

    before_ids = patients(before_rows)
    before = preview.reconcile(triage, before_rows)
    before_counts = counts(before)

    if any(
        "triage_review_complete" not in r
        for r in triage
    ):
        raise RuntimeError(
            "Triage completion field missing from export"
        )

    eligible = sum(
        str(r.get("triage_decision", "")).strip() == "1"
        and str(r.get("triage_review_complete", "")).strip() == "2"
        for r in triage
    )

    verified = 0
    status = "completed"
    error = ""

    # Invoke the existing, validated import routine when requested.
    # Its private receipts remain authoritative for recovery.

    if args.mode == "transfer" and before_counts.get(
        "new_candidate", 0
    ):
        command = [
            sys.executable,
            str(
                Path(__file__).with_name(
                    "shg_triage_import.py"
                )
            ),
            "--private",
            str(private),
            "--confirm",
            CONFIRM,
        ]

        if args.limit is not None:
            command.extend(["--limit", str(args.limit)])

        result = subprocess.run(
            command,
            capture_output=True,
            text=True,
            check=False,
        )

        if result.stdout:
            print(
                result.stdout,
                end="" if result.stdout.endswith("\n") else "\n",
            )

        if result.stderr:
            print(result.stderr, file=sys.stderr)

        if result.returncode != 0:
            status = "import_failed_review_receipts"
            error = (
                "Import script returned nonzero exit status; "
                "inspect private receipts"
            )
        else:
            match = re.search(
                r"Verified new registry records this run:\s*(\d+)",
                result.stdout,
            )

            if match is None:
                status = "verification_uncertain"
                error = (
                    "Import script did not report a verified count"
                )
            else:
                verified = int(match.group(1))

    # Re-extract the destination after the operation.

    after_rows = preview.export_records(registry_token)
    after_ids = patients(after_rows)

    after = preview.reconcile(triage, after_rows)
    after_counts = counts(after)

    new_ids = after_ids - before_ids

    new_transfers = new_transfer_rows(after_rows, new_ids, triage)
    breakdown = report_breakdown(
        triage, before_counts, before_ids, after_ids
    )

    if args.mode == "preview" and new_ids:
        status = "registry_changed_during_preview"

    if (
        args.mode == "transfer"
        and status == "completed"
        and len(new_ids) != verified
    ):
        status = "verification_uncertain"
        error = (
            "New registry patient count differs from "
            "verified import count"
        )

    if len(after_ids) < len(before_ids):
        status = "registry_record_loss_review"
        error = (
            "Distinct registry patient count decreased during run"
        )

    review_labels = (
        "missing_psource_id_review",
        "duplicate_psource_id_review",
        "missing_emis_id_review",
        "duplicate_emis_id_review",
        "conflicting_matches_review",
        "incomplete_identity_review",
    )

    completed_at = datetime.now(timezone.utc)

    metrics = {
        "time_utc": completed_at.isoformat(timespec="seconds"),
        "time_display": completed_at.strftime("%d %b %Y, %H:%M UTC"),
        "operation": args.mode,
        "run_status": status,
        "triage_project": TRIAGE_PID,
        "registry_project": REGISTRY_PID,
        "triage_total": len(triage),
        "eligible": eligible,
        "not_eligible": after_counts.get("not_eligible", 0),
        "registry_before": len(before_ids),
        "registry_after": len(after_ids),
        "registry_export_rows_after": len(after_rows),
        "new_candidates_before": before_counts.get(
            "new_candidate", 0
        ),
        "new_candidates_after": after_counts.get(
            "new_candidate", 0
        ),
        "existing_match_after": after_counts.get(
            "already_registered_or_review", 0
        ),
        "identity_review_after": sum(
            after_counts.get(k, 0)
            for k in review_labels
        ),
        "new_registry_patients": len(new_ids),
        "verified_imports": verified,
    }

    write_outputs(
        run_dir, metrics, before, after, new_transfers, breakdown
    )

    if error:
        (run_dir / "ERROR.txt").write_text(
            error + "\n", encoding="utf-8"
        )

    # Forward slashes are valid Windows separators and remain stable when
    # Stata reads a macro-expanded path (unlike \t and \r in backslash paths).
    pointer.write_text(
        run_dir.as_posix() + "\n", encoding="utf-8"
    )

    print(f"Run status: {status}")
    print(
        "Distinct registry patients: "
        f"{len(before_ids)} -> {len(after_ids)}"
    )
    print(
        f"New patients this run: {len(new_ids)}; "
        f"verified imports: {verified}"
    )
    print(
        "New candidates remaining: "
        f"{metrics['new_candidates_after']}"
    )
    print(f"Private run folder: {run_dir}")

    return 0 if status == "completed" else 1


if __name__ == "__main__":
    sys.exit(main())
