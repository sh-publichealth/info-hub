/*
SHG diabetes triage transfer: compatibility preview entry point

The maintained controller is shg_triage_report.do.
This wrapper preserves the earlier read-only command.
*/

version 19.0

if "$SHG_STATA" == "" {
    display as error ///
        "SHG paths are not loaded. Restart Stata using the SHG-enabled profile."
    exit 601
}

do "$SHG_STATA/registry/shg_triage_report.do" preview
