/*
SHG diabetes triage: Stata entry point

Production projects: triage 1087 -> registry 1077

Usage from any Stata working directory:

    do "$SHG_STATA/registry/shg_triage_report.do" preview

    do "$SHG_STATA/registry/shg_triage_report.do" ///
        transfer TRANSFER-1087-TO-1077

An optional positive third argument limits an authorised run:

    do "$SHG_STATA/registry/shg_triage_report.do" ///
        transfer TRANSFER-1087-TO-1077 1

The controller uses only the SHG global paths loaded by profile.do.
It deliberately does not change the caller's working directory.
*/

version 19.0

args mode confirmation limit

if `"`mode'"' == "" local mode "preview"

if "$SHG_STATA" == "" {
    display as error ///
        "SHG paths are not loaded. Restart Stata using the SHG-enabled profile."
    exit 601
}

display as result ""
display as result "SHG TRIAGE TRANSFER COMMAND ACCEPTED"
display as text   "Mode: `mode' | Triage 1087 -> Registry 1077"
display as text   "Preparing reconciliation; please wait..."
display as result ""

capture noisily do ///
    "$SHG_STATA/registry/shg_triage_report_worker.do" ///
    `"`mode'"' `"`confirmation'"' `"`limit'"'

local worker_rc = _rc

if `worker_rc' {
    exit `worker_rc'
}
