** Generate both v5 reports from the latest existing raw export.
** No API call and no changes to the legacy DQ workflow.
** args: SCRIPT_DIRECTORY DATA_ROOT VISIT_MAP
version 19
args script_dir data_root visit_map
if `"`script_dir'"' == "" local script_dir "C:/yoshimi-hot/output/analyse-sth/sh003-diabetes-registry/info-hub/scripts/stata/tmr/monitoring"
if `"`data_root'"' == "" local data_root "C:/yoshimi-hot/output/analyse-sth/sh007-total-meal-replacement/stata"
if `"`visit_map'"' == "" local visit_map "`script_dir'/config/tmr-visit-map.csv"
do "`script_dir'/tmr-02-prepare-data-v3.do" "`data_root'" "`visit_map'"
do "`script_dir'/tmr-04-monitor-report-v5.do" "`data_root'"
do "`script_dir'/tmr-04-monitor-report-v5-noname.do" "`data_root'"
