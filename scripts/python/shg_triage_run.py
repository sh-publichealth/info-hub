
"""SHG triage run controller: reconciliation, optional import and report inputs.

TEST PROJECTS ONLY: triage 1091, registry 1090.
Requires the existing shg_redcap_transfer.py and shg_triage_import_test.py.
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


TRIAGE_PID = "1091"
REGISTRY_PID = "1090"
CONFIRM = "TEST-1091-TO-1090"


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


def q(value):
    """Quote a YAML string using JSON-compatible double quotes."""
    return json.dumps(str(value), ensure_ascii=False)


def write_outputs(run_dir, metrics, before_decisions, after_decisions):
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
        f"  environment: {q('test')}",
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
        f"  reconciliation: {q(str(run_dir / 'reconciliation_PRIVATE.csv'))}",
        f"  report_metrics: {q(str(run_dir / 'report_metrics.csv'))}",
        f"  pdf: {q(str(run_dir / 'triage-transfer-report.pdf'))}",
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


def main():
    parser = argparse.ArgumentParser()

    parser.add_argument("--private", required=True)
    parser.add_argument(
        "--mode",
        choices=("preview", "transfer"),
        default="preview",
    )
    parser.add_argument("--limit", type=int, default=5)
    parser.add_argument("--confirm", default="")

    args = parser.parse_args()

    if args.mode == "transfer" and args.confirm != CONFIRM:
        parser.error(
            "Test transfer requires --confirm TEST-1091-TO-1090"
        )

    if args.mode == "transfer" and not 1 <= args.limit <= 5:
        parser.error("Test transfers require --limit between 1 and 5")

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
        private / "config" / "triage_token.txt"
    )

    registry_token = preview.read_token(
        private / "config" / "registry_token.txt"
    )

    if preview.get_project_id(triage_token) != TRIAGE_PID:
        raise RuntimeError(
            "Wrong triage project; expected test project 1091"
        )

    if preview.get_project_id(registry_token) != REGISTRY_PID:
        raise RuntimeError(
            "Wrong registry project; expected test project 1090"
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

    # Invoke the existing, tested import routine when requested.
    # Its private receipts remain authoritative for recovery.

    if args.mode == "transfer" and before_counts.get(
        "new_candidate", 0
    ):
        command = [
            sys.executable,
            str(
                Path(__file__).with_name(
                    "shg_triage_import_test.py"
                )
            ),
            "--private",
            str(private),
            "--limit",
            str(args.limit),
            "--confirm",
            CONFIRM,
        ]

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

    metrics = {
        "time_utc": datetime.now(timezone.utc).isoformat(
            timespec="seconds"
        ),
        "operation": args.mode,
        "run_status": status,
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

    write_outputs(run_dir, metrics, before, after)

    if error:
        (run_dir / "ERROR.txt").write_text(
            error + "\n", encoding="utf-8"
        )

    pointer.write_text(
        str(run_dir) + "\n", encoding="utf-8"
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

