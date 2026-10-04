** SHG negative tests v2 — explicit SHG paths; independent of c(pwd).
version 19
args script_dir
set more off
if `"`script_dir'"' == "" local script_dir "C:/yoshimi-hot/output/analyse-sth/sh003-diabetes-registry/info-hub/scripts/stata/tmr/monitoring"
local tmr_root "C:/yoshimi-hot/output/analyse-sth/sh007-total-meal-replacement/stata"
local fixture_root "`script_dir'/testing"
local negative_root "`tmr_root'/testing/tmr-monitoring-v4/negative-run"
confirm file "`fixture_root'/config/tmr-visit-map.csv"
confirm file "`script_dir'/tmr-02-prepare-data-v2.do"
foreach fixture in negative_unmapped_event negative_conflicting_weight {
    confirm file "`fixture_root'/data_raw/`fixture'.dta"
}
capture mkdir "`tmr_root'/testing"
capture mkdir "`tmr_root'/testing/tmr-monitoring-v4"
capture mkdir "`negative_root'"
capture mkdir "`negative_root'/data_raw"
foreach fixture in negative_unmapped_event negative_conflicting_weight {
    copy "`fixture_root'/data_raw/`fixture'.dta" "`negative_root'/data_raw/tmr_full_redcap_api_extract_latest.dta", replace
    capture noisily do "`script_dir'/tmr-02-prepare-data-v2.do" "`negative_root'" "`fixture_root'/config/tmr-visit-map.csv"
    local actual_rc = _rc
    if `actual_rc' != 459 {
        di as error "Negative test `fixture' returned `actual_rc'; expected 459."
        exit 459
    }
    di as result "PASS: `fixture' stopped with r(459), as expected."
}
capture log close
