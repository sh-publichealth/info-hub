# Triage-to-registry production operation

## Fixed project route

The operational workflow transfers eligible patients from Diabetes Triage
project 1087 to Diabetes Registry project 1077.

The private configuration folder must contain:

- `triage_token_live.txt` for project 1087;
- `registry_token_live.txt` for project 1077.

Each file contains one API token. Tokens and all patient-level outputs remain
outside Git under `$SHG_PRIVATE`.

## Eligibility and matching

A patient is eligible for transfer only when `triage_decision == 1` and
`triage_review_complete == 2`. The reconciliation excludes ambiguous records,
duplicate identifiers and incomplete identity information from automatic
transfer. Triage records are never modified.

## Operating sequence

1. Run the read-only preview.
2. Review the private PDF and reconciliation CSV.
3. Resolve records classified for identity review.
4. Run the authorised transfer.
5. Confirm the completion screen, PDF, YAML and transferred-patient CSV.

The dialog transfers the complete reviewed candidate set. A positive optional
command-line limit is available for a deliberately bounded first run.

Every transfer rechecks the destination immediately before each import,
allocates the registry ID through REDCap auto-numbering, reads the destination
back, compares transferred values and records a private receipt. An uncertain
write is never automatically retried.

## Private outputs

Run folders remain below:

`$SHG_PRIVATE/work/triage-transfer/runs`

Persistent import receipts remain below:

`$SHG_PRIVATE/work/triage-transfer/import-receipts`
