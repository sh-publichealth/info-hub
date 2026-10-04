** Live SHG TMR monitoring runner v4 — no synthetic files or test runners.
** Uses the latest existing real raw extract and participant status dataset.
** args: SCRIPT_DIRECTORY DATA_ROOT VISIT_MAP
version 19
args script_dir data_root visit_map
set more off
if `"`script_dir'"' == "" local script_dir "C:/yoshimi-hot/output/analyse-sth/sh003-diabetes-registry/info-hub/scripts/stata/tmr/monitoring"
if `"`data_root'"' == "" local data_root "C:/yoshimi-hot/output/analyse-sth/sh007-total-meal-replacement/stata"
if `"`visit_map'"' == "" local visit_map "`script_dir'/config/tmr-visit-map.csv"
confirm file "`data_root'/data_raw/tmr_full_redcap_api_extract_latest.dta"
confirm file "`data_root'/data_clean/tmr_monitor_participant_status.dta"
foreach script in tmr-visit-map-audit-v3.do tmr-02-prepare-data-v3.do ///
    tmr-04-monitor-report-v7.do tmr-04-monitor-report-v7-noname.do {
    confirm file "`script_dir'/`script'"
}
di as result "REAL TMR DATA ROOT: `data_root'"
di as result "VISIT MAP: `visit_map'"
** Automatically map confirmed extra visits, then check event coverage before PDFs.
do "`script_dir'/tmr-visit-map-audit-v3.do" "`data_root'" "`visit_map'"
do "`script_dir'/tmr-02-prepare-data-v3.do" "`data_root'" "`visit_map'"
do "`script_dir'/tmr-04-monitor-report-v7.do" "`data_root'"
do "`script_dir'/tmr-04-monitor-report-v7-noname.do" "`data_root'"
di as result "Live monitoring PDFs saved to: `data_root'/output/pdf"
