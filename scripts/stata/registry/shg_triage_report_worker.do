
/*
SHG diabetes triage: reporting worker and private operational PDF

TEST ONLY: triage 1091 -> registry 1090

Called by shg_triage_report.do. Do not run this worker directly.
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
* 1. Check the SHG workstation globals loaded by profile.do
* ------------------------------------------------------------

if "$SHG_PRIVATE" == "" | "$SHG_PYTHON" == "" | ///
    "$SHG_PYTHON_EXE" == "" {

    display as error ///
        "SHG paths are not loaded. Restart Stata using the SHG-enabled profile."
    exit 601
}

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
* 2. Start-of-run display
* ------------------------------------------------------------

display as result ""
display as result "SHG DIABETES REGISTRY: TRIAGE-TO-REGISTRY TRANSFER"
display as text   "Starting `mode' run | Test projects: triage 1091 -> registry 1090"

if `"`mode'"' == "preview" {
    display as text "This is read-only: no REDCap records will be changed."
}
else {
    display as text "Authorised test transfer: the registry will be re-read and verified."
}

display as text "Running Python reconciliation now; please wait..."
display as result ""

* ------------------------------------------------------------
* 3. Execute the Python workflow
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
* 4. Locate the private results
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
* Also accept a pointer written by an earlier Windows controller.
local run_dir : subinstr local run_dir "\" "/", all

local metrics_file "`run_dir'/report_metrics.csv"

capture confirm file "`metrics_file'"

if _rc {
    display as error ///
        "Missing report_metrics.csv: `run_dir'"
    exit 601
}

* ------------------------------------------------------------
* 5. Read report inputs
* ------------------------------------------------------------

preserve

import delimited using ///
    "`metrics_file'", ///
    clear varnames(1) stringcols(_all)

if _N != 1 {
    restore
    display as error ///
        "Expected exactly one row in report_metrics.csv."
    exit 459
}

* CSV headers are designed to be valid Stata variable names.
* Do not rely on Stata's truncation of long source headers.

foreach name in operation run_status time_utc time_display ///
    triage_project registry_project ///
    triage_total eligible not_eligible ///
    registry_before registry_after ///
    registry_export_rows_after ///
    new_candidates_before new_candidates_after ///
    existing_match_after ///
    identity_review_after new_registry_patients verified_imports {

    local `name' = `name'[1]
}

restore

local breakdown_file "`run_dir'/report_breakdown.csv"

capture confirm file "`breakdown_file'"

if _rc {
    display as error "Missing report_breakdown.csv: `run_dir'"
    exit 601
}

preserve

import delimited using ///
    "`breakdown_file'", ///
    clear varnames(1) stringcols(_all)

local breakdown_rows = _N

forvalues i = 1/`breakdown_rows' {
    local breakdown_type`i' = row_type[`i']
    local breakdown_measure`i' = measure[`i']
    local breakdown_count`i' = count[`i']
}

restore

local new_transfer_file "`run_dir'/new_transfers_PRIVATE.csv"

capture confirm file "`new_transfer_file'"

if _rc {
    display as error ///
        "Missing new-transfers file: `new_transfer_file'"
    exit 601
}

preserve

import delimited using ///
    "`new_transfer_file'", ///
    clear varnames(1) stringcols(_all)

local new_transfers = _N

forvalues i = 1/`new_transfers' {
    local transfer_id`i' = registry_internal_id[`i']
    local transfer_psource`i' = psource_id[`i']
    local transfer_family`i' = family_name[`i']
    local transfer_first`i' = first_name[`i']
    local transfer_dob`i' = date_of_birth[`i']
}

restore

* ------------------------------------------------------------
* 6. Create the private PDF
* ------------------------------------------------------------

capture putpdf clear

putpdf begin

putpdf paragraph, font(,19) halign(center)
putpdf text ("SHG Diabetes Registry"), bold

putpdf paragraph, font(,13) halign(center)
putpdf text ("Triage transfer and reconciliation")

putpdf paragraph
putpdf table projects = (1,1)
putpdf table projects(1,1) = ///
    ("TEST PROJECTS: TRIAGE `triage_project' TO REGISTRY `registry_project'"), ///
    bold bgcolor(D9EAF7)
putpdf table projects(1,1), bgcolor(D9EAF7) halign(center)

putpdf paragraph
putpdf text ///
    ("Completed: `time_display' | Operation: `operation' | Status: `run_status'")

putpdf paragraph
putpdf table confidential = (1,1)
putpdf table confidential(1,1) = ("CONFIDENTIAL"), bold bgcolor(F4CCCC)
putpdf table confidential(1,1), bgcolor(F4CCCC) halign(center)

* ------------------------------------------------------------
* 7. Summary table
* ------------------------------------------------------------

local summary_rows = `breakdown_rows' + 1

matrix count_widths = (80, 20)
putpdf table counts = (`summary_rows',2), ///
    width(100%) width(count_widths)

putpdf table counts(1,1) = ("Measure"), bold
putpdf table counts(1,2) = ("Count"), bold

forvalues i = 1/`breakdown_rows' {
    local r = `i' + 1

    if "`breakdown_type`i''" == "section" {
        putpdf table counts(`r',1) = ///
            ("`breakdown_measure`i''"), bold bgcolor(EAF2F8)
        putpdf table counts(`r',2) = (""), bgcolor(EAF2F8)
        putpdf table counts(`r',1), bgcolor(EAF2F8)
        putpdf table counts(`r',2), bgcolor(EAF2F8)
    }
    else {
        putpdf table counts(`r',1) = ///
            ("`breakdown_measure`i''")
        putpdf table counts(`r',2) = ///
            ("`breakdown_count`i''")
    }
}

putpdf paragraph
putpdf text ("Patients transferred in this run"), bold

if `new_transfers' == 0 {
    putpdf paragraph
    putpdf text ("No patients were transferred in this run.")
}
else {
    local transfer_rows = `new_transfers' + 1

    putpdf table transfers = (`transfer_rows', 5)

    putpdf table transfers(1,1) = ("Registry internal ID"), bold
    putpdf table transfers(1,2) = ("PatientSource ID"), bold
    putpdf table transfers(1,3) = ("Surname"), bold
    putpdf table transfers(1,4) = ("First name"), bold
    putpdf table transfers(1,5) = ("Date of birth"), bold

    forvalues i = 1/`new_transfers' {
        local r = `i' + 1
        putpdf table transfers(`r',1) = ("`transfer_id`i''")
        putpdf table transfers(`r',2) = ("`transfer_psource`i''")
        putpdf table transfers(`r',3) = ("`transfer_family`i''")
        putpdf table transfers(`r',4) = ("`transfer_first`i''")
        putpdf table transfers(`r',5) = ("`transfer_dob`i''")
    }
}

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

if `"`run_status'"' != "completed" {
    display as error ///
        "Run requires investigation: `run_status'"
    exit 459
}

quietly {
    noisily display as result ///
        "SHG TRIAGE TRANSFER COMPLETED"

    noisily display as text ///
        "Operation: `operation' | Status: `run_status' | Run: `time_utc'"

    noisily display as result ///
        "New registry patients transferred: `new_registry_patients'"

    noisily display as text ///
        "Verified imports: `verified_imports' | New candidates remaining: `new_candidates_after'"

    noisily display as text ///
        "Existing registry match or review: `existing_match_after' | Other identity review: `identity_review_after'"

    noisily display as text ///
        "Registry patients: `registry_before' -> `registry_after'"

    noisily display as result ///
        "Private PDF: `run_dir'/triage-transfer-report.pdf"

    noisily display as result ///
        "Private YAML: `run_dir'/summary.yml"

    noisily display as result ///
        "Private transferred-patient list: `run_dir'/new_transfers_PRIVATE.csv"
}
