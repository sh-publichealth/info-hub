** SHG synthetic test runner v2 — explicit SHG paths; independent of c(pwd).
** Optional first argument: absolute SHG monitoring script directory.
** Test data, logs and outputs remain under the original TMR data project.
version 19
args script_dir
set more off
if `"`script_dir'"' == "" local script_dir "C:/yoshimi-hot/output/analyse-sth/sh003-diabetes-registry/info-hub/scripts/stata/tmr/monitoring"
local tmr_root "C:/yoshimi-hot/output/analyse-sth/sh007-total-meal-replacement/stata"
local fixture_root "`script_dir'/testing"
local test_root "`tmr_root'/testing/tmr-monitoring-v4"
local test_map "`test_root'/config/tmr-visit-map.csv"

** Check package inputs before creating/copying the isolated fixtures.
confirm file "`fixture_root'/data_raw/tmr_full_redcap_api_extract_latest.dta"
confirm file "`fixture_root'/data_clean/tmr_monitor_participant_status.dta"
confirm file "`fixture_root'/config/tmr-visit-map.csv"
confirm file "`fixture_root'/tmr-test-assertions-v1.do"
confirm file "`script_dir'/tmr-02-prepare-data-v2.do"
confirm file "`script_dir'/tmr-04-monitor-report-v4.do"
confirm file "`script_dir'/tmr-04-monitor-report-v4-noname.do"

capture mkdir "`tmr_root'/testing"
capture mkdir "`test_root'"
capture mkdir "`test_root'/data_raw"
capture mkdir "`test_root'/data_clean"
capture mkdir "`test_root'/config"
copy "`fixture_root'/data_raw/tmr_full_redcap_api_extract_latest.dta" "`test_root'/data_raw/tmr_full_redcap_api_extract_latest.dta", replace
copy "`fixture_root'/data_clean/tmr_monitor_participant_status.dta" "`test_root'/data_clean/tmr_monitor_participant_status.dta", replace
copy "`fixture_root'/config/tmr-visit-map.csv" "`test_map'", replace

do "`script_dir'/tmr-02-prepare-data-v2.do" "`test_root'" "`test_map'"
do "`fixture_root'/tmr-test-assertions-v1.do" "`test_root'"
do "`script_dir'/tmr-04-monitor-report-v4.do" "`test_root'"
do "`script_dir'/tmr-04-monitor-report-v4-noname.do" "`test_root'"
di as result "Synthetic reports are in: `test_root'/output/pdf"
di as result "The synthetic names begin Synthetic; synthetic IDs are in the 90000 range."
