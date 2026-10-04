** Verify fail-closed cases in a disposable subfolder of testing/.
version 19
args script_dir
if `"`script_dir'"' == "" local script_dir "`c(pwd)'/scripts/stata/tmr/monitoring"
local test_root "`script_dir'/testing"
local negative_root "`test_root'/negative-run"
capture mkdir "`negative_root'"
capture mkdir "`negative_root'/data_raw"
foreach fixture in negative_unmapped_event negative_conflicting_weight {
    copy "`test_root'/data_raw/`fixture'.dta" "`negative_root'/data_raw/tmr_full_redcap_api_extract_latest.dta", replace
    capture noisily do "`script_dir'/tmr-02-prepare-data-v2.do" "`negative_root'" "`test_root'/config/tmr-visit-map.csv"
    local actual_rc = _rc
    if `actual_rc' != 459 {
        di as error "Negative test `fixture' returned `actual_rc'; expected 459."
        exit 459
    }
    di as result "PASS: `fixture' stopped with r(459), as expected."
}
capture log close
