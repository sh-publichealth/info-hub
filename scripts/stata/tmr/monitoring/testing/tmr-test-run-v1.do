** Run from the repository root after unzipping. Uses only testing/ data.
** Optional first argument is the absolute scripts/stata/tmr/monitoring folder.
version 19
args script_dir
set more off
if `"`script_dir'"' == "" local script_dir "`c(pwd)'/scripts/stata/tmr/monitoring"
local test_root "`script_dir'/testing"
local test_map "`test_root'/config/tmr-visit-map.csv"
confirm file "`test_root'/data_raw/tmr_full_redcap_api_extract_latest.dta"
do "`script_dir'/tmr-02-prepare-data-v2.do" "`test_root'" "`test_map'"
do "`test_root'/tmr-test-assertions-v1.do" "`test_root'"
do "`script_dir'/tmr-04-monitor-report-v4.do" "`test_root'"
do "`script_dir'/tmr-04-monitor-report-v4-noname.do" "`test_root'"
di as result "Synthetic reports are in: `test_root'/output/pdf"
di as result "The synthetic names begin Synthetic; synthetic IDs are in the 90000 range."
