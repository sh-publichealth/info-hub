** SHG synthetic test runner v3 — explicit SHG paths; independent of c(pwd).
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
confirm file "`fixture_root'/tmr-test-assertions-v2.do"
confirm file "`script_dir'/tmr-02-prepare-data-v3.do"
confirm file "`script_dir'/tmr-04-monitor-report-v5.do"
confirm file "`script_dir'/tmr-04-monitor-report-v5-noname.do"

capture mkdir "`tmr_root'/testing"
capture mkdir "`test_root'"
capture mkdir "`test_root'/data_raw"
capture mkdir "`test_root'/data_clean"
capture mkdir "`test_root'/config"
copy "`fixture_root'/data_raw/tmr_full_redcap_api_extract_latest.dta" "`test_root'/data_raw/tmr_full_redcap_api_extract_latest.dta", replace
copy "`fixture_root'/data_clean/tmr_monitor_participant_status.dta" "`test_root'/data_clean/tmr_monitor_participant_status.dta", replace
copy "`fixture_root'/config/tmr-visit-map.csv" "`test_map'", replace

** Verify the intended tiny fixture before invoking any preparation script.
quietly use "`test_root'/data_raw/tmr_full_redcap_api_extract_latest.dta", clear
assert _N == 62
assert inlist(record_id,"305-90001","305-90017","306-90003","305-90004","305-90005","306-90006")
di as result "SYNTHETIC TEST ROOT: `test_root'"
di as result "SYNTHETIC VISIT MAP: `test_map'"
di as result "Confirmed 62 synthetic raw rows; now preparing the test dataset."

do "`script_dir'/tmr-02-prepare-data-v3.do" "`test_root'" "`test_map'"
do "`fixture_root'/tmr-test-assertions-v2.do" "`test_root'"
do "`script_dir'/tmr-04-monitor-report-v5.do" "`test_root'"
do "`script_dir'/tmr-04-monitor-report-v5-noname.do" "`test_root'"
di as result "Synthetic reports are in: `test_root'/output/pdf"
di as result "The synthetic names begin Synthetic; synthetic IDs are in the 90000 range."
