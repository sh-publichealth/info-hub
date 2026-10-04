** SHG TMR complete weekly workflow v1 (1 October 2026).
** Replaces tmr-00-weekly-run.do as the weekly entry point.
** Uses REAL SHG data and explicit SHG paths, independent of the working folder.
** 01: Refresh REDCap raw extract and participant status using the existing extractor.
** 02/03: Preserve the original preparation + DQ v2 workflow unchanged.
** 04: Run live monitoring v4 (automatic map audit v3, preparation v3,
**     identifiable report v7, and non-identifiable report v7).
** Two preparation datasets are intentional: the existing DQ and updated
** monitoring reports read different files. Do not remove the original preparation.
version 19
set more off

** Check the full dependency set BEFORE refreshing data or generating reports.
foreach required in tmr-01-redcap-extract.do tmr-02-prepare-data.do ///
    tmr-03-dq-report-v2.do tmr-run-monitoring-v4.do ///
    tmr-visit-map-audit-v3.do tmr-02-prepare-data-v3.do ///
    tmr-04-monitor-report-v7.do tmr-04-monitor-report-v7-noname.do {
    confirm file "C:/yoshimi-hot/output/analyse-sth/sh003-diabetes-registry/info-hub/scripts/stata/tmr/monitoring/`required'"
}

** Use literal paths below: existing leaf scripts clear macros during setup.
** Errors propagate naturally; later steps are not run after a failed DO file.
di as result "WEEKLY STEP 1: Refresh real REDCap data and participant status."
do "C:/yoshimi-hot/output/analyse-sth/sh003-diabetes-registry/info-hub/scripts/stata/tmr/monitoring/tmr-01-redcap-extract.do"

** Check confirmed visit coverage before either reporting workflow begins.
** This is also checked by the monitoring runner when it is run independently.
di as result "WEEKLY STEP 2: Update and validate the visit map."
do "C:/yoshimi-hot/output/analyse-sth/sh003-diabetes-registry/info-hub/scripts/stata/tmr/monitoring/tmr-visit-map-audit-v3.do" ///
    "C:/yoshimi-hot/output/analyse-sth/sh007-total-meal-replacement/stata" ///
    "C:/yoshimi-hot/output/analyse-sth/sh003-diabetes-registry/info-hub/scripts/stata/tmr/monitoring/config/tmr-visit-map.csv"

di as result "WEEKLY STEP 3: Prepare the existing DQ dataset."
do "C:/yoshimi-hot/output/analyse-sth/sh003-diabetes-registry/info-hub/scripts/stata/tmr/monitoring/tmr-02-prepare-data.do"

di as result "WEEKLY STEP 4: Create the existing data-quality report."
do "C:/yoshimi-hot/output/analyse-sth/sh003-diabetes-registry/info-hub/scripts/stata/tmr/monitoring/tmr-03-dq-report-v2.do"

di as result "WEEKLY STEP 5: Prepare updated monitoring data and create both reports."
do "C:/yoshimi-hot/output/analyse-sth/sh003-diabetes-registry/info-hub/scripts/stata/tmr/monitoring/tmr-run-monitoring-v4.do"

di as result "Weekly TMR extraction, DQ and monitoring workflow completed."
di as result "PDF folder: C:/yoshimi-hot/output/analyse-sth/sh007-total-meal-replacement/stata/output/pdf"
