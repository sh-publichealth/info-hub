# SHG TMR weekly workflow and archive guide

Extract this ZIP into the info-hub repository root, preserving the folder structure.
It adds tmr-00-weekly-run-v1.do, archive-tmr-monitoring-v1.ps1 and this guide. It does not overwrite the visit map,
change the extractor, modify the DQ code, or move/archive any files.

## Weekly command

```stata
do "C:/yoshimi-hot/output/analyse-sth/sh003-diabetes-registry/info-hub/scripts/stata/tmr/monitoring/tmr-00-weekly-run-v1.do"
```

Use this instead of tmr-00-weekly-run.do for the complete weekly process.
It checks all required DO files, refreshes the existing real REDCap extract and
participant status, updates/checks the visit map, runs the original preparation
and DQ v2 report, then runs monitoring v4. Monitoring v4 calls audit v3 again
(no CSV write when unchanged), preparation v3, and both report v7 files.

The first map check happens before the DQ PDF is generated. The second check
keeps monitoring v4 usable as an independent entry point for an existing extract.
An error stops subsequent steps; outputs from earlier successful steps may remain.

Two preparation passes are required by the current arrangement:
- DQ v2 reads tmr_full_analysis_dataset_latest.dta from the original preparation.
- Monitoring v7 reads the separate v3 prepared dataset.

DQ calculations and its PDF naming remain unchanged. Monitoring PDFs retain
ordinary dated names without version numbers. All paths are explicit SHG paths;
the controller does not rely on Stata's current working directory or globals.
The existing extractor remains responsible for API configuration.

## Keep active in scripts/stata/tmr/monitoring

| File | Why needed |
|---|---|
| tmr-00-weekly-run-v1.do | New complete weekly entry point |
| tmr-01-redcap-extract.do | Refresh raw data and participant status |
| tmr-02-prepare-data.do | Required by the unchanged DQ workflow |
| tmr-03-dq-report-v2.do | Existing current DQ report |
| tmr-run-monitoring-v4.do | Current monitoring controller |
| tmr-visit-map-audit-v3.do | Automatic map maintenance |
| tmr-02-prepare-data-v3.do | Current monitoring preparation |
| tmr-04-monitor-report-v7.do | Identifiable monitoring report |
| tmr-04-monitor-report-v7-noname.do | Non-identifiable monitoring report |
| config/tmr-visit-map.csv | Live visit map |
| README-tmr-weekly-v1.md | This current guide |

## Archive after the new weekly run succeeds

These are unused by the new weekly controller and its checked dependencies.
Move them; do not delete them. Retire any shortcut or scheduled task that calls
an old entry point before moving that entry point and its dependencies.
Suggested archive root: monitoring/archive/2026-10-01/. Preserve subfolders.

| Files/folder | Reason |
|---|---|
| tmr-00-weekly-run.do | Old weekly entry point; replaced by v1 |
| run-reports-legacy.do | Legacy entry point; archive if it is retired |
| tmr-02-prepare-data-v2.do | Superseded monitoring preparation |
| tmr-03-dq-report.do | Not used; weekly process uses DQ v2 |
| tmr-04-monitor-report.do | Old monitoring report |
| tmr-04-monitor-report-v2.do and tmr-04-monitor-report-v2-noname.do | Old monitoring reports |
| tmr-04-monitor-report-v3.do and tmr-04-monitor-report-v3-noname.do | Old monitoring reports |
| tmr-04-monitor-report-v4.do and tmr-04-monitor-report-v4-noname.do | Old monitoring reports |
| tmr-04-monitor-report-v5.do and tmr-04-monitor-report-v5-noname.do | Old monitoring reports |
| tmr-04-monitor-report-v6.do and tmr-04-monitor-report-v6-noname.do | Old monitoring reports |
| tmr-run-monitoring-v1.do, tmr-run-monitoring-v2.do, tmr-run-monitoring-v3.do | Superseded controllers |
| tmr-visit-map-audit-v1.do, tmr-visit-map-audit-v2.do | Superseded audits |
| README-tmr-monitoring-v4.md | Superseded instructions |
| testing/ (entire folder) | Synthetic fixtures and tests; unused by live workflow |

Keep timestamped visit-map backups for rollback; they are not read by the runner.
They can be moved to the archive separately, retaining their filenames.
Do not archive the active config/tmr-visit-map.csv or real private input datasets.

This classification is based on your supplied folder listing, uploaded weekly
controller, the current monitoring scripts, and DQ v2 at repository commit
85f84102c1d9f094068c0c6cf363cc38aa6dc930. The contents of run-reports-legacy.do
and any external scheduled tasks were not provided; it is conditional on retirement.

## Validation

Verified the new controller's dependency list and call order, explicit SHG paths,
absence of synthetic references, unchanged DQ inputs, and ZIP structure.
Stata is not installed in the build environment. Run the new weekly controller
locally and check all three PDFs before archiving the old entry point.

## PowerShell archive commands

Run from the info-hub repository root. First run the new weekly DO file and
check all three PDFs. Update any shortcut or scheduled task to the new controller.

Read-only preview:

```powershell
.\scripts\stata\tmr\monitoring\archive-tmr-monitoring-v1.ps1
```

Archive the superseded files:

```powershell
.\scripts\stata\tmr\monitoring\archive-tmr-monitoring-v1.ps1 -Apply
```

Optional PowerShell dry run of the apply path:

```powershell
.\scripts\stata\tmr\monitoring\archive-tmr-monitoring-v1.ps1 -Apply -WhatIf
```

If run-reports-legacy.do is also retired, add -IncludeLegacyRunner to the preview
and apply commands. It is retained by default because its contents were not supplied.

The script uses an explicit allowlist, checks the active dependencies, and moves
testing/ as a whole. It creates a unique dated folder under monitoring/archive/,
with archive-plan.csv (per-item move status) and archive-files.csv (file paths,
bytes and SHA256 hashes). It never deletes or overwrites archive items. If a move
fails, the status manifest records items already moved; inspect it before retrying.
Unknown files and live map backups are retained. The script itself remains active.

PowerShell is unavailable in the build environment; the script received static
checks but must be previewed and executed on your Windows machine.
