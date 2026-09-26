/*
SHG diabetes triage: protected Stata entry point

TEST ONLY: triage 1091 -> registry 1090

Usage from any Stata working directory:

    do "$SHG_STATA/registry/shg_triage_report.do" preview

    do "$SHG_STATA/registry/shg_triage_report.do" ///
        transfer 5 TEST-1091-TO-1090

This wrapper temporarily switches to $SHG_REPO, runs the SHG worker,
and restores the caller's working directory on both success and failure.
*/

version 19.0

args mode limit confirmation

if "$SHG_REPO" == "" | "$SHG_STATA" == "" {
    display as error ///
        "SHG paths are not loaded. Restart Stata using the SHG-enabled profile."
    exit 601
}

local caller_pwd `"`c(pwd)'"'

capture cd "$SHG_REPO"

if _rc {
    display as error "SHG repository folder not found: $SHG_REPO"
    exit 601
}

capture noisily do ///
    "$SHG_STATA/registry/shg_triage_report_worker.do" ///
    `"`mode'"' `"`limit'"' `"`confirmation'"'

local worker_rc = _rc

capture cd `"`caller_pwd'"'

if _rc {
    display as error ///
        "SHG run finished, but Stata could not restore the previous working directory."
    exit 459
}

if `worker_rc' {
    exit `worker_rc'
}

