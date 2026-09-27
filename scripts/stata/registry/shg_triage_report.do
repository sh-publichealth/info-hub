/*
SHG diabetes triage: Stata entry point

TEST ONLY: triage 1091 -> registry 1090

Usage from any Stata working directory:

    do "$SHG_STATA/registry/shg_triage_report.do" preview

    do "$SHG_STATA/registry/shg_triage_report.do" ///
        transfer 5 TEST-1091-TO-1090

The controller uses only the SHG global paths loaded by profile.do.
It deliberately does not change the caller's working directory.
*/

version 19.0

args mode limit confirmation

if "$SHG_STATA" == "" {
    display as error ///
        "SHG paths are not loaded. Restart Stata using the SHG-enabled profile."
    exit 601
}

capture noisily do ///
    "$SHG_STATA/registry/shg_triage_report_worker.do" ///
    `"`mode'"' `"`limit'"' `"`confirmation'"'

local worker_rc = _rc

if `worker_rc' {
    exit `worker_rc'
}

