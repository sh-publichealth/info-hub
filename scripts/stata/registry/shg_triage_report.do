
/*
SHG diabetes triage: Stata controller and private operational PDF

TEST ONLY: triage 1091 -> registry 1090

Usage from the info-hub repository root:

    do scripts/stata/registry/shg_triage_report.do preview

    do scripts/stata/registry/shg_triage_report.do ///
        transfer 5 TEST-1091-TO-1090
*/

version 19.0

args mode limit confirmation

if `"`mode'"' == "" local mode "preview"

if !inlist(`"`mode'"', "preview", "transfer") {
    display as error "Mode must be preview or transfer."
    exit 198
}

if `"`limit'"' == "" local limit "5"

if `"`mode'"' == "transfer" & ///
    `"`confirmation'"' != "TEST-1091-TO-1090" {

    display as error ///
        "Transfer requires the TEST-1091-TO-1090 confirmation argument."

    exit 198
}

* ------------------------------------------------------------
* 1. Load the existing workstation configuration
* ------------------------------------------------------------

capture confirm file ///
    "scripts/stata/config/shg_paths_LOCAL.do"

if _rc {
    display as error ///
        "Run from the info-hub root and configure shg_paths_LOCAL.do first."
    exit 601
}

do "scripts/stata/config/shg_paths_LOCAL.do"

capture confirm file "$SHG_PYTHON_EXE"

if _rc {
    display as error "SHG virtual-environment Python not found."
    exit 601
}

capture confirm file "$SHG_PYTHON/shg_triage_run.py"

if _rc {
    display as error "SHG Python run controller not found."
    exit 601
}

* ------------------------------------------------------------
* 2. Execute the Python workflow
* ------------------------------------------------------------

local pointer ///
    "$SHG_PRIVATE/work/triage-transfer/latest_run_path.txt"

* Remove the previous pointer so that a failed Python invocation
* cannot accidentally produce a report from an earlier run.

capture erase `"`pointer'"'

if `"`mode'"' == "preview" {

    shell "$SHG_PYTHON_EXE" ///
        "$SHG_PYTHON/shg_triage_run.py" ///
        --private "$SHG_PRIVATE" ///
        --mode preview
}
else {

    shell "$SHG_PYTHON_EXE" ///
        "$SHG_PYTHON/shg_triage_run.py" ///
        --private "$SHG_PRIVATE" ///
        --mode transfer ///
        --limit `limit' ///
        --confirm TEST-1091-TO-1090
}

* ------------------------------------------------------------
* 3. Locate the private results
* ------------------------------------------------------------

capture confirm file `"`pointer'"'

if _rc {
    display as error ///
        "Python did not produce a run summary. Review the output above."
    exit 459
}

file open shg_path using `"`pointer'"', read text
file read shg_path run_dir
file close shg_path

local run_dir = strtrim(`"`run_dir'"')

capture confirm file ///
    `"`run_dir'/report_metrics.csv"'

if _rc {
    display as error ///
        "Missing report_metrics.csv: `run_dir'"
    exit 601
}

* ------------------------------------------------------------
* 4. Read report metrics
* ------------------------------------------------------------

preserve

import delimited using ///
    `"`run_dir'/report_metrics.csv"', ///
    clear varnames(1) stringcols(_all)

if _N != 1 {
    restore
    display as error ///
        "Expected exactly one row in report_metrics.csv."
    exit 459
}

* Shorten the long CSV variable name after import.
* Stata permits a maximum of 32 characters.

rename _already_registered_or_review_after existing_match_after

foreach name in operation run_status time_utc ///
    triage_total eligible not_eligible ///
    registry_before registry_after ///
    registry_export_rows_after ///
    new_candidates_before new_candidates_after ///
    existing_match_after ///
    identity_review_after new_registry_patients verified_imports {

    local `name' = `name'[1]
}

restore

* ------------------------------------------------------------
* 5. Create the private PDF
* ------------------------------------------------------------

capture putpdf clear

putpdf begin

putpdf paragraph, font(,19) halign(center)
putpdf text ("SHG Diabetes Registry"), bold

putpdf paragraph, font(,13) halign(center)
putpdf text ("Triage transfer and reconciliation")

putpdf paragraph
putpdf text ("Test projects: triage 1091 to registry 1090")

putpdf paragraph
putpdf text ///
    ("Run: `time_utc' | Operation: `operation' | Status: `run_status'")

putpdf paragraph
putpdf text ///
    ("This report contains aggregate operational counts only. Patient-level review files remain private.")

* ------------------------------------------------------------
* 6. Summary table
* ------------------------------------------------------------

putpdf table counts = (13,2)

putpdf table counts(1,1) = ("Measure")
putpdf table counts(1,2) = ("Count")

putpdf table counts(2,1) = ("Triage records")
putpdf table counts(2,2) = ("`triage_total'")

putpdf table counts(3,1) = ("Eligible triage records")
putpdf table counts(3,2) = ("`eligible'")

putpdf table counts(4,1) = ("Not eligible")
putpdf table counts(4,2) = ("`not_eligible'")

putpdf table counts(5,1) = ///
    ("Distinct registry patients before run")
putpdf table counts(5,2) = ("`registry_before'")

putpdf table counts(6,1) = ("New candidates before run")
putpdf table counts(6,2) = ("`new_candidates_before'")

putpdf table counts(7,1) = ("New registry patients this run")
putpdf table counts(7,2) = ("`new_registry_patients'")

putpdf table counts(8,1) = ("Verified imports this run")
putpdf table counts(8,2) = ("`verified_imports'")

putpdf table counts(9,1) = ///
    ("Distinct registry patients after run")
putpdf table counts(9,2) = ("`registry_after'")

putpdf table counts(10,1) = ///
    ("Registry export rows (including repeats)")
putpdf table counts(10,2) = ///
    ("`registry_export_rows_after'")

putpdf table counts(11,1) = ("New candidates remaining")
putpdf table counts(11,2) = ("`new_candidates_after'")

putpdf table counts(12,1) = ///
    ("Existing registry match or review")
putpdf table counts(12,2) = ///
    ("`existing_match_after'")
    
putpdf table counts(13,1) = ///
    ("Other identity-review classifications")
putpdf table counts(13,2) = ///
    ("`identity_review_after'")

* ------------------------------------------------------------
* 7. Interpretation and operational notes
* ------------------------------------------------------------

putpdf paragraph
putpdf text ("Notes"), bold

putpdf paragraph
putpdf text ///
    ("Registry patients are distinct internal_redcap_id values. Export rows may include several repeating instruments per patient.")

putpdf paragraph
putpdf text ///
    ("Existing registry match or review is not yet a confirmed-identity classification. Onboarding-only fields may remain incomplete after enrolment.")

if `"`run_status'"' != "completed" {

    putpdf paragraph

    putpdf text ///
        ("ATTENTION: The run did not complete normally. Check ERROR.txt and import receipts before any retry."), ///
        bold
}

* ------------------------------------------------------------
* 8. Save the report
* ------------------------------------------------------------

putpdf save ///
    `"`run_dir'/triage-transfer-report.pdf"', replace

display as result ///
    "Private PDF: `run_dir'/triage-transfer-report.pdf"

display as result ///
    "Private YAML: `run_dir'/summary.yml"

if `"`run_status'"' != "completed" {
    display as error ///
        "Run requires investigation: `run_status'"
    exit 459
}
