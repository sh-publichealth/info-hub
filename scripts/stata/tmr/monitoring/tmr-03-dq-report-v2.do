** HEADER -----------------------------------------------------
**  DO-FILE METADATA
    //  algorithm name             tmr-03-dq-report-v2.do
    //  project:                   SH007 total meal replacement
    //  analysts:                  Ian HAMBLETON
    //  date last modified         14-Aug-2026
    //  workflow step              3 of 4
    //  algorithm task             Create the TMR data quality PDF report

    ** General algorithm set-up
    version 19
    clear all
    macro drop _all
    set more off
    set linesize 120

    ** Folder locations
    global projectroot "C:\yoshimi-hot\output\analyse-sth\sh007-total-meal-replacement\stata"
    global rawdir      "$projectroot\data_raw"
    global cleandir    "$projectroot\data_clean"
    global outputdir   "$projectroot\output"
    global figdir      "$projectroot\output\figures"
    global pdfdir      "$projectroot\output\pdf"
    global log         "$projectroot\logs"

    ** Create folders if they do not already exist
    capture mkdir "$outputdir"
    capture mkdir "$figdir"
    capture mkdir "$pdfdir"
    capture mkdir "$log"

    ** Close any open log file and open a new log file
    capture log close
    log using "$log\tmr-03-dq-report", replace
** HEADER -----------------------------------------------------


** =========================================================================
** PART 1. LOAD PREPARED FULL ANALYSIS DATASET
** =========================================================================

use "$cleandir\tmr_full_analysis_dataset_latest.dta", clear

label data "TMR data quality report input dataset"


** -------------------------------------------------------------------------
** Create report date locals
** -------------------------------------------------------------------------

local report_date = "`c(current_date)'"
local report_date_file = subinstr("`c(current_date)'", " ", "_", .)
local report_date_file = subinstr("`report_date_file'", "-", "_", .)

local today_num = date("`c(current_date)'", "DMY")
local today_display : display %tdDD/NN/CCYY `today_num'


** -------------------------------------------------------------------------
** Confirm or create key variables expected by this DQ report
**
** These variables should normally exist because they are created by:
**
**     tmr-02-prepare-data.do
**
** The capture blocks below make this report less fragile if an early test
** dataset is missing one of the derived variables.
** -------------------------------------------------------------------------

capture confirm variable p_has_prog
if _rc {
    capture confirm variable has_prog
    if !_rc {
        bysort record_id: egen p_has_prog = max(has_prog)
    }
    else {
        gen byte p_has_prog = 0
    }
}

capture confirm variable has_pmeas
if _rc {
    gen byte has_pmeas = 0
}

capture confirm variable has_pwd
if _rc {
    gen byte has_pwd = 0
}

capture confirm variable has_pae
if _rc {
    gen byte has_pae = 0
}

capture confirm variable prog_visit_date
if _rc {
    gen prog_visit_date = .
    format prog_visit_date %dM_d,_CY
}

capture confirm variable prog_visit_num
if _rc {
    gen prog_visit_num = .
}

capture confirm variable prog_visit_block
if _rc {
    gen prog_visit_block = .
}

capture confirm variable prog_visit_label
if _rc {
    gen prog_visit_label = .
}

capture confirm variable baseline_prog_date
if _rc {
    di as error "Required variable baseline_prog_date is missing."
    di as error "Run tmr-02-prepare-data.do before this report."
    exit 111
}


** -------------------------------------------------------------------------
** STRICT DATA-QUALITY COHORT FILTER
**
** The DQ report concerns people who have actually entered the TMR programme.
** We use the same operational definition as the monitoring report:
**
**     entered programme = at least one recorded baseline programme visit
**
** baseline_prog_date is longitudinal and may not be populated on the same
** row selected later as the participant tag. Establish entry status across
** ALL rows first, then retain every row belonging to programme starters.
** This keeps screening, adverse-event and withdrawal information available
** for DQ checks among enrolled participants while excluding screening-only
** people entirely from the report.
** -------------------------------------------------------------------------

gen byte dq_started_programme_row = !missing(baseline_prog_date)

bysort record_id: egen byte dq_started_programme = max(dq_started_programme_row)

drop dq_started_programme_row

label variable dq_started_programme ///
    "Participant has at least one baseline programme visit"

egen byte _dq_source_ptag = tag(record_id)

quietly count if _dq_source_ptag == 1
local n_source_participants = r(N)

quietly count if _dq_source_ptag == 1 & dq_started_programme == 1
local n_entered_programme = r(N)

local n_screening_only = `n_source_participants' - `n_entered_programme'

di as result "DQ source participants before cohort filter: `n_source_participants'"
di as result "Programme entrants retained for DQ: `n_entered_programme'"
di as result "Screening-only participants excluded from DQ: `n_screening_only'"

if `n_entered_programme' == 0 {
    di as error "No participants with a recorded baseline programme visit were found."
    di as error "DQ report not created because the programme-entry cohort is empty."
    exit 2000
}

keep if dq_started_programme == 1
drop _dq_source_ptag

** Recalculate report-level dataset counts AFTER the strict cohort filter.
count
local n_rows = r(N)

quietly levelsof record_id, local(record_ids)
local n_participants : word count `record_ids'

if `n_participants' != `n_entered_programme' {
    di as error "ERROR: retained DQ cohort does not equal the number of programme entrants."
    di as error "Entrants: `n_entered_programme'; retained: `n_participants'"
    exit 459
}

capture confirm variable weeks_from_baseline
if _rc {
    gen weeks_from_baseline = .
}

capture confirm variable consent_date
if _rc {
    gen consent_date = .
    format consent_date %dM_d,_CY
}

capture confirm variable baseline_weight
if _rc {
    gen baseline_weight = .
}

capture confirm variable baseline_hba1c
if _rc {
    gen baseline_hba1c = .
}

capture confirm variable baseline_hba1c_copy
if _rc {
    gen baseline_hba1c_copy = .
}


** -------------------------------------------------------------------------
** Create display helper variables for the DQ report
** -------------------------------------------------------------------------

gen str80 dq_name = ""

capture confirm variable fname_padmin
local has_fname = !_rc

capture confirm variable lname_padmin
local has_lname = !_rc

if `has_fname' == 1 & `has_lname' == 1 {
    replace dq_name = strtrim(fname_padmin + " " + lname_padmin)
}
else if `has_fname' == 1 {
    replace dq_name = strtrim(fname_padmin)
}
else if `has_lname' == 1 {
    replace dq_name = strtrim(lname_padmin)
}

replace dq_name = "Not recorded" if missing(dq_name) | dq_name == ""


** Visit label for display
gen str40 dq_visit_label = ""

capture decode prog_visit_label, gen(_dq_visit_label)
if !_rc {
    replace dq_visit_label = _dq_visit_label if !missing(_dq_visit_label)
    drop _dq_visit_label
}

replace dq_visit_label = string(prog_visit_num, "%9.0g") ///
    if dq_visit_label == "" & !missing(prog_visit_num)

replace dq_visit_label = "Not assigned" if dq_visit_label == ""


** Visit date for display
gen str12 dq_visit_date = ""

replace dq_visit_date = string(prog_visit_date, "%tdDD/NN/CCYY") ///
    if !missing(prog_visit_date)

replace dq_visit_date = "Missing" if dq_visit_date == ""


** Participant tag: one row per participant
sort record_id
by record_id: gen byte dq_ptag = (_n == 1)


** -------------------------------------------------------------------------
** Retain participant-level screening context flags
**
** These flags remain useful for identifying inconsistencies among programme
** entrants, but they no longer determine inclusion in the DQ report.
**
**     exclusion_screen_2 == 1 means an exclusion criterion is present.
**     interested_screen_2 == 2 means the person answered "No" to interest in
**     taking part in the TMR pilot.
** -------------------------------------------------------------------------

gen byte dq_screen_ineligible = 0
capture confirm variable exclusion_screen_2
if !_rc {
    replace dq_screen_ineligible = 1 if exclusion_screen_2 == 1
}

gen byte dq_not_interested = 0
capture confirm variable interested_screen_2
if !_rc {
    replace dq_not_interested = 1 if interested_screen_2 == 2
}

bysort record_id: egen p_screen_ineligible = max(dq_screen_ineligible)
bysort record_id: egen p_not_interested = max(dq_not_interested)

label variable dq_screen_ineligible "DQ flag: row indicates screening exclusion criterion present"
label variable dq_not_interested "DQ flag: row indicates not interested in TMR pilot"
label variable p_screen_ineligible "Participant has screening exclusion criterion present"
label variable p_not_interested "Participant answered not interested in TMR pilot"


** -------------------------------------------------------------------------
** Participant belongs to the DQ programme-entry cohort
**
** Screening eligibility and interest are NOT used to exclude anyone at this
** stage. Once a participant has a recorded baseline programme visit they are
** in scope for every applicable DQ check, even if an earlier screening field
** is inconsistent. This prevents screening status from silently suppressing
** genuine data-quality problems among programme entrants.
** -------------------------------------------------------------------------

gen byte dq_expected_baseline = dq_started_programme == 1

label variable dq_expected_baseline ///
    "DQ scope: participant has entered programme"


** =========================================================================
** PART 2. SUMMARY COUNTS
** =========================================================================

quietly count if dq_ptag == 1 & p_has_prog == 1
local n_programme = r(N)

quietly count if dq_ptag == 1 & !missing(baseline_prog_date)
local n_baseline = r(N)

quietly count if dq_ptag == 1 & dq_expected_baseline == 1 & missing(baseline_prog_date)
local n_no_baseline = r(N)

quietly count if dq_ptag == 1 & dq_expected_baseline == 1 & !missing(baseline_prog_date) & missing(baseline_weight)
local n_missing_base_weight = r(N)

quietly count if dq_ptag == 1 & dq_expected_baseline == 1 & !missing(baseline_prog_date) & ///
    missing(baseline_hba1c) & missing(baseline_hba1c_copy)
local n_missing_base_hba1c = r(N)

quietly count if has_pmeas == 1 & missing(prog_visit_date)
local n_missing_visit_date = r(N)

quietly count if !missing(prog_visit_date) & prog_visit_date > `today_num'
local n_future_visit = r(N)

quietly count if !missing(prog_visit_date) & !missing(consent_date) & prog_visit_date < consent_date
local n_visit_before_consent = r(N)

quietly count if !missing(weeks_from_baseline) & weeks_from_baseline < 0
local n_negative_weeks = r(N)


** Current phase counts
quietly count if dq_ptag == 1 & p_has_prog == 1
local n_phase_total = r(N)

preserve
    keep if p_has_prog == 1 & !missing(prog_visit_num)
    bysort record_id: egen _max_visit = max(prog_visit_num)
    bysort record_id: keep if _n == 1

    gen byte _current_block = .
    replace _current_block = 1 if _max_visit == 1
    replace _current_block = 2 if inrange(_max_visit, 2, 7)
    replace _current_block = 3 if inrange(_max_visit, 8, 11)
    replace _current_block = 4 if inrange(_max_visit, 12, 16)
    replace _current_block = 5 if inrange(_max_visit, 17, 20)
    replace _current_block = 6 if _max_visit > 20 & !missing(_max_visit)

    quietly count if _current_block == 1
    local n_current_baseline = r(N)

    quietly count if _current_block == 2
    local n_current_tmr = r(N)

    quietly count if _current_block == 3
    local n_current_food = r(N)

    quietly count if _current_block == 4
    local n_current_year1 = r(N)

    quietly count if _current_block == 5
    local n_current_year2 = r(N)

    quietly count if _current_block == 6
    local n_current_extra = r(N)
restore


** Withdrawal and adverse event headline counts
quietly count if dq_ptag == 1 & has_pwd == 1
local n_withdrawal = r(N)

quietly count if dq_ptag == 1 & has_pae == 1
local n_ae = r(N)


** =========================================================================
** PART 3. BUILD DQ ISSUE REGISTER
** =========================================================================


** -------------------------------------------------------------------------
** DQ issue register
**
** The report creates a temporary issue register with one row per flagged
** issue. This makes it easy to:
**
**     - count issues by severity
**     - count issues by type
**     - list detailed issues in the PDF
**
** Severity:
**     High   = likely to affect governance, safety, programme delivery, or
**              primary monitoring
**     Medium = important review issue, but less urgent
**     Review = plausible value or operational issue worth checking
** -------------------------------------------------------------------------

tempfile dq_issues

postfile dqpost ///
    str4 check_id ///
    str10 severity ///
    str45 issue ///
    str40 record_id ///
    str80 name ///
    str40 visit ///
    str12 visit_date ///
    str32 variable ///
    str40 value ///
    str90 action ///
    using `dq_issues', replace


** -------------------------------------------------------------------------
** C01. Programme entrant has no baseline visit (cohort integrity check)
**
** Under the strict programme-entry cohort this should normally be zero.
** It is retained as a cohort-integrity safeguard.
** -------------------------------------------------------------------------

preserve
    keep if dq_ptag == 1 & dq_expected_baseline == 1 & missing(baseline_prog_date)

    forvalues i = 1/`=_N' {
        local rid    = record_id[`i']
        local pname  = dq_name[`i']

        post dqpost ///
            ("C01") ///
            ("High") ///
            ("No baseline visit") ///
            ("`rid'") ///
            ("`pname'") ///
            ("Not assigned") ///
            ("Missing") ///
            ("baseline_prog_date") ///
            ("Missing") ///
            ("Check whether baseline visit has been entered")
    }
restore


** -------------------------------------------------------------------------
** C02. Baseline weight missing
** -------------------------------------------------------------------------

preserve
    keep if dq_ptag == 1 & dq_expected_baseline == 1 & !missing(baseline_prog_date) & missing(baseline_weight)

    forvalues i = 1/`=_N' {
        local rid    = record_id[`i']
        local pname  = dq_name[`i']
        local bdate  = string(baseline_prog_date[`i'], "%tdDD/NN/CCYY")

        post dqpost ///
            ("C02") ///
            ("High") ///
            ("Baseline weight missing") ///
            ("`rid'") ///
            ("`pname'") ///
            ("Baseline") ///
            ("`bdate'") ///
            ("baseline_weight") ///
            ("Missing") ///
            ("Enter or confirm baseline weight")
    }
restore


** -------------------------------------------------------------------------
** C03. Baseline HbA1c missing
**
** The prepared dataset may contain baseline_hba1c and/or baseline_hba1c_copy.
** We flag only when both are missing.
** -------------------------------------------------------------------------

preserve
    keep if dq_ptag == 1 & dq_expected_baseline == 1 & !missing(baseline_prog_date) & ///
        missing(baseline_hba1c) & missing(baseline_hba1c_copy)

    forvalues i = 1/`=_N' {
        local rid    = record_id[`i']
        local pname  = dq_name[`i']
        local bdate  = string(baseline_prog_date[`i'], "%tdDD/NN/CCYY")

        post dqpost ///
            ("C03") ///
            ("Medium") ///
            ("Baseline HbA1c missing") ///
            ("`rid'") ///
            ("`pname'") ///
            ("Baseline") ///
            ("`bdate'") ///
            ("baseline_hba1c") ///
            ("Missing") ///
            ("Check whether baseline HbA1c is available")
    }
restore


** -------------------------------------------------------------------------
** C04. Programme measurements present but programme visit date missing
** -------------------------------------------------------------------------

preserve
    keep if has_pmeas == 1 & missing(prog_visit_date)

    forvalues i = 1/`=_N' {
        local rid    = record_id[`i']
        local pname  = dq_name[`i']

        post dqpost ///
            ("C04") ///
            ("High") ///
            ("Programme visit date missing") ///
            ("`rid'") ///
            ("`pname'") ///
            ("Not assigned") ///
            ("Missing") ///
            ("prog_visit_date") ///
            ("Missing") ///
            ("Enter visit date for programme measurements")
    }
restore


** -------------------------------------------------------------------------
** C05. Programme visit date is in the future
** -------------------------------------------------------------------------

preserve
    keep if !missing(prog_visit_date) & prog_visit_date > `today_num'

    forvalues i = 1/`=_N' {
        local rid    = record_id[`i']
        local pname  = dq_name[`i']
        local visit  = dq_visit_label[`i']
        local vdate  = dq_visit_date[`i']

        post dqpost ///
            ("C05") ///
            ("High") ///
            ("Visit date in future") ///
            ("`rid'") ///
            ("`pname'") ///
            ("`visit'") ///
            ("`vdate'") ///
            ("prog_visit_date") ///
            ("Future date") ///
            ("Check visit date")
    }
restore


** -------------------------------------------------------------------------
** C06. Programme visit before consent date
** -------------------------------------------------------------------------

preserve
    keep if !missing(prog_visit_date) & !missing(consent_date) & prog_visit_date < consent_date

    forvalues i = 1/`=_N' {
        local rid    = record_id[`i']
        local pname  = dq_name[`i']
        local visit  = dq_visit_label[`i']
        local vdate  = dq_visit_date[`i']
        local cdate  = string(consent_date[`i'], "%tdDD/NN/CCYY")

        post dqpost ///
            ("C06") ///
            ("High") ///
            ("Visit before consent") ///
            ("`rid'") ///
            ("`pname'") ///
            ("`visit'") ///
            ("`vdate'") ///
            ("consent_date") ///
            ("`cdate'") ///
            ("Check consent and visit dates")
    }
restore


** -------------------------------------------------------------------------
** C07. Negative weeks from baseline
** -------------------------------------------------------------------------

preserve
    keep if !missing(weeks_from_baseline) & weeks_from_baseline < 0

    forvalues i = 1/`=_N' {
        local rid    = record_id[`i']
        local pname  = dq_name[`i']
        local visit  = dq_visit_label[`i']
        local vdate  = dq_visit_date[`i']
        local value  = string(weeks_from_baseline[`i'], "%9.0f")

        post dqpost ///
            ("C07") ///
            ("High") ///
            ("Negative weeks from baseline") ///
            ("`rid'") ///
            ("`pname'") ///
            ("`visit'") ///
            ("`vdate'") ///
            ("weeks_from_baseline") ///
            ("`value'") ///
            ("Check baseline and visit dates")
    }
restore


** -------------------------------------------------------------------------
** C08. Baseline only and overdue by more than 21 days
**
** Active participant is defined pragmatically as:
**     - expected to have a baseline
**     - baseline date present
**     - no withdrawal flag
**     - latest programme visit number is 1
**     - more than 21 days since baseline
** -------------------------------------------------------------------------

preserve
    keep if dq_expected_baseline == 1 & !missing(baseline_prog_date)

    bysort record_id: egen _max_visit = max(prog_visit_num)
    bysort record_id: egen _has_withdrawal = max(has_pwd)

    keep if dq_ptag == 1
    keep if _max_visit == 1 & _has_withdrawal != 1 & (`today_num' - baseline_prog_date) > 21

    forvalues i = 1/`=_N' {
        local rid    = record_id[`i']
        local pname  = dq_name[`i']
        local bdate  = string(baseline_prog_date[`i'], "%tdDD/NN/CCYY")
        local value  = string(`today_num' - baseline_prog_date[`i'], "%9.0f")

        post dqpost ///
            ("C08") ///
            ("Medium") ///
            ("Baseline only and overdue") ///
            ("`rid'") ///
            ("`pname'") ///
            ("Baseline") ///
            ("`bdate'") ///
            ("days since baseline") ///
            ("`value'") ///
            ("Check whether TMR visit 1 is due or missing")
    }
restore


** -------------------------------------------------------------------------
** C09. TMR phase gap greater than 21 days between visits
**
** This uses consecutive dated programme visits. It is designed as a simple
** operational flag rather than a formal protocol-deviation definition.
** -------------------------------------------------------------------------

preserve
    keep if !missing(prog_visit_date) & !missing(prog_visit_num)
    sort record_id prog_visit_date prog_visit_num

    by record_id: gen _prev_date = prog_visit_date[_n-1]
    by record_id: gen _prev_visit = prog_visit_num[_n-1]
    gen _gap_days = prog_visit_date - _prev_date

    keep if inrange(prog_visit_num, 2, 7) & ///
        inrange(_prev_visit, 1, 6) & ///
        _gap_days > 21 & !missing(_gap_days)

    forvalues i = 1/`=_N' {
        local rid    = record_id[`i']
        local pname  = dq_name[`i']
        local visit  = dq_visit_label[`i']
        local vdate  = dq_visit_date[`i']
        local value  = string(_gap_days[`i'], "%9.0f")

        post dqpost ///
            ("C09") ///
            ("Medium") ///
            ("Long TMR visit gap") ///
            ("`rid'") ///
            ("`pname'") ///
            ("`visit'") ///
            ("`vdate'") ///
            ("gap days") ///
            ("`value'") ///
            ("Review missed or delayed TMR follow-up")
    }
restore


** -------------------------------------------------------------------------
** C10-C18. Clinical value plausibility
**
** These are deliberately focused on key variables used for programme
** monitoring. They are review flags, not automatic errors.
** -------------------------------------------------------------------------

** C10. Weight
capture confirm variable weight
if !_rc {
    preserve
        keep if !missing(weight) & (weight < 40 | weight > 200)

        forvalues i = 1/`=_N' {
            local rid    = record_id[`i']
            local pname  = dq_name[`i']
            local visit  = dq_visit_label[`i']
            local vdate  = dq_visit_date[`i']
            local value  = string(weight[`i'], "%9.1f")

            post dqpost ///
                ("C10") ///
                ("Review") ///
                ("Implausible weight") ///
                ("`rid'") ///
                ("`pname'") ///
                ("`visit'") ///
                ("`vdate'") ///
                ("weight") ///
                ("`value'") ///
                ("Check weight value or unit")
        }
    restore
}

** C11. Height
capture confirm variable height_padmin
if !_rc {
    preserve
        keep if !missing(height_padmin) & (height_padmin < 120 | height_padmin > 220)

        forvalues i = 1/`=_N' {
            local rid    = record_id[`i']
            local pname  = dq_name[`i']
            local value  = string(height_padmin[`i'], "%9.1f")

            post dqpost ///
                ("C11") ///
                ("Review") ///
                ("Implausible height") ///
                ("`rid'") ///
                ("`pname'") ///
                ("Participant admin") ///
                ("") ///
                ("height_padmin") ///
                ("`value'") ///
                ("Check height value or unit")
        }
    restore
}

** C12. BMI from screening, if available
capture confirm variable bmi_screen_2
if !_rc {
    preserve
        keep if !missing(bmi_screen_2) & (bmi_screen_2 < 15 | bmi_screen_2 > 70)

        forvalues i = 1/`=_N' {
            local rid    = record_id[`i']
            local pname  = dq_name[`i']
            local value  = string(bmi_screen_2[`i'], "%9.1f")

            post dqpost ///
                ("C12") ///
                ("Review") ///
                ("Implausible BMI") ///
                ("`rid'") ///
                ("`pname'") ///
                ("Eligibility screening") ///
                ("") ///
                ("bmi_screen_2") ///
                ("`value'") ///
                ("Check height, weight, or BMI")
        }
    restore
}

** C13. Systolic blood pressure
foreach bp in sbp1 sbp2 sbp3 {
    capture confirm variable `bp'
    if !_rc {
        preserve
            keep if !missing(`bp') & (`bp' < 70 | `bp' > 250)

            forvalues i = 1/`=_N' {
                local rid    = record_id[`i']
                local pname  = dq_name[`i']
                local visit  = dq_visit_label[`i']
                local vdate  = dq_visit_date[`i']
                local value  = string(`bp'[`i'], "%9.0f")

                post dqpost ///
                    ("C13") ///
                    ("Review") ///
                    ("Implausible SBP") ///
                    ("`rid'") ///
                    ("`pname'") ///
                    ("`visit'") ///
                    ("`vdate'") ///
                    ("`bp'") ///
                    ("`value'") ///
                    ("Check systolic BP value")
            }
        restore
    }
}

** C14. Diastolic blood pressure
foreach bp in dbp1 dbp2 dbp3 {
    capture confirm variable `bp'
    if !_rc {
        preserve
            keep if !missing(`bp') & (`bp' < 40 | `bp' > 150)

            forvalues i = 1/`=_N' {
                local rid    = record_id[`i']
                local pname  = dq_name[`i']
                local visit  = dq_visit_label[`i']
                local vdate  = dq_visit_date[`i']
                local value  = string(`bp'[`i'], "%9.0f")

                post dqpost ///
                    ("C14") ///
                    ("Review") ///
                    ("Implausible DBP") ///
                    ("`rid'") ///
                    ("`pname'") ///
                    ("`visit'") ///
                    ("`vdate'") ///
                    ("`bp'") ///
                    ("`value'") ///
                    ("Check diastolic BP value")
            }
        restore
    }
}

** C15. DBP greater than or equal to SBP
forvalues j = 1/3 {
    capture confirm variable sbp`j'
    local has_sbp = !_rc
    capture confirm variable dbp`j'
    local has_dbp = !_rc

    if `has_sbp' == 1 & `has_dbp' == 1 {
        preserve
            keep if !missing(sbp`j') & !missing(dbp`j') & dbp`j' >= sbp`j'

            forvalues i = 1/`=_N' {
                local rid    = record_id[`i']
                local pname  = dq_name[`i']
                local visit  = dq_visit_label[`i']
                local vdate  = dq_visit_date[`i']
                local value  = string(dbp`j'[`i'], "%9.0f") + "/" + string(sbp`j'[`i'], "%9.0f")

                post dqpost ///
                    ("C15") ///
                    ("Review") ///
                    ("DBP greater/equal SBP") ///
                    ("`rid'") ///
                    ("`pname'") ///
                    ("`visit'") ///
                    ("`vdate'") ///
                    ("BP reading `j'") ///
                    ("`value'") ///
                    ("Check BP reading order")
            }
        restore
    }
}

** C16. Glucose
capture confirm variable glucose
if !_rc {
    preserve
        keep if !missing(glucose) & (glucose < 2 | glucose > 35)

        forvalues i = 1/`=_N' {
            local rid    = record_id[`i']
            local pname  = dq_name[`i']
            local visit  = dq_visit_label[`i']
            local vdate  = dq_visit_date[`i']
            local value  = string(glucose[`i'], "%9.1f")

            post dqpost ///
                ("C16") ///
                ("Review") ///
                ("Implausible glucose") ///
                ("`rid'") ///
                ("`pname'") ///
                ("`visit'") ///
                ("`vdate'") ///
                ("glucose") ///
                ("`value'") ///
                ("Check glucose value")
        }
    restore
}

** C17. HbA1c
capture confirm variable hba1c
if !_rc {
    preserve
        keep if !missing(hba1c) & (hba1c < 20 | hba1c > 160)

        forvalues i = 1/`=_N' {
            local rid    = record_id[`i']
            local pname  = dq_name[`i']
            local visit  = dq_visit_label[`i']
            local vdate  = dq_visit_date[`i']
            local value  = string(hba1c[`i'], "%9.1f")

            post dqpost ///
                ("C17") ///
                ("Review") ///
                ("Implausible HbA1c") ///
                ("`rid'") ///
                ("`pname'") ///
                ("`visit'") ///
                ("`vdate'") ///
                ("hba1c") ///
                ("`value'") ///
                ("Check HbA1c value or unit")
        }
    restore
}

** C18. eGFR
capture confirm variable egfr
if !_rc {
    preserve
        keep if !missing(egfr) & (egfr < 0 | egfr > 150)

        forvalues i = 1/`=_N' {
            local rid    = record_id[`i']
            local pname  = dq_name[`i']
            local visit  = dq_visit_label[`i']
            local vdate  = dq_visit_date[`i']
            local value  = string(egfr[`i'], "%9.1f")

            post dqpost ///
                ("C18") ///
                ("Review") ///
                ("Implausible eGFR") ///
                ("`rid'") ///
                ("`pname'") ///
                ("`visit'") ///
                ("`vdate'") ///
                ("egfr") ///
                ("`value'") ///
                ("Check eGFR value")
        }
    restore
}


** -------------------------------------------------------------------------
** C19-C22. Large change between consecutive visits
**
** These are review flags. They may be true changes, but they are worth
** checking because they can also indicate date, unit, or entry errors.
** -------------------------------------------------------------------------

** C19. Weight change >7 kg between consecutive dated programme rows
capture confirm variable weight
if !_rc {
    preserve
        keep if !missing(prog_visit_date)
        sort record_id prog_visit_date prog_visit_num

        by record_id: gen _prev_weight = weight[_n-1]
        gen _chg_weight = weight - _prev_weight if !missing(weight) & !missing(_prev_weight)

        keep if abs(_chg_weight) > 7 & !missing(_chg_weight)

        forvalues i = 1/`=_N' {
            local rid    = record_id[`i']
            local pname  = dq_name[`i']
            local visit  = dq_visit_label[`i']
            local vdate  = dq_visit_date[`i']
            local value  = string(_chg_weight[`i'], "%9.1f")

            post dqpost ///
                ("C19") ///
                ("Review") ///
                ("Large weight change") ///
                ("`rid'") ///
                ("`pname'") ///
                ("`visit'") ///
                ("`vdate'") ///
                ("weight change") ///
                ("`value' kg") ///
                ("Check adjacent visit weights and dates")
        }
    restore
}

** C20. HbA1c change >30 mmol/mol between consecutive dated programme rows
capture confirm variable hba1c
if !_rc {
    preserve
        keep if !missing(prog_visit_date)
        sort record_id prog_visit_date prog_visit_num

        by record_id: gen _prev_hba1c = hba1c[_n-1]
        gen _chg_hba1c = hba1c - _prev_hba1c if !missing(hba1c) & !missing(_prev_hba1c)

        keep if abs(_chg_hba1c) > 30 & !missing(_chg_hba1c)

        forvalues i = 1/`=_N' {
            local rid    = record_id[`i']
            local pname  = dq_name[`i']
            local visit  = dq_visit_label[`i']
            local vdate  = dq_visit_date[`i']
            local value  = string(_chg_hba1c[`i'], "%9.1f")

            post dqpost ///
                ("C20") ///
                ("Review") ///
                ("Large HbA1c change") ///
                ("`rid'") ///
                ("`pname'") ///
                ("`visit'") ///
                ("`vdate'") ///
                ("HbA1c change") ///
                ("`value'") ///
                ("Check adjacent HbA1c values and dates")
        }
    restore
}

** C21. SBP average change >50 mmHg between consecutive dated programme rows
capture confirm variable sbp_avg
if !_rc {
    preserve
        keep if !missing(prog_visit_date)
        sort record_id prog_visit_date prog_visit_num

        by record_id: gen _prev_sbp = sbp_avg[_n-1]
        gen _chg_sbp = sbp_avg - _prev_sbp if !missing(sbp_avg) & !missing(_prev_sbp)

        keep if abs(_chg_sbp) > 50 & !missing(_chg_sbp)

        forvalues i = 1/`=_N' {
            local rid    = record_id[`i']
            local pname  = dq_name[`i']
            local visit  = dq_visit_label[`i']
            local vdate  = dq_visit_date[`i']
            local value  = string(_chg_sbp[`i'], "%9.1f")

            post dqpost ///
                ("C21") ///
                ("Review") ///
                ("Large SBP change") ///
                ("`rid'") ///
                ("`pname'") ///
                ("`visit'") ///
                ("`vdate'") ///
                ("SBP change") ///
                ("`value'") ///
                ("Check adjacent BP values and dates")
        }
    restore
}

** C22. Glucose change >15 mmol/L between consecutive dated programme rows
capture confirm variable glucose
if !_rc {
    preserve
        keep if !missing(prog_visit_date)
        sort record_id prog_visit_date prog_visit_num

        by record_id: gen _prev_glucose = glucose[_n-1]
        gen _chg_glucose = glucose - _prev_glucose if !missing(glucose) & !missing(_prev_glucose)

        keep if abs(_chg_glucose) > 15 & !missing(_chg_glucose)

        forvalues i = 1/`=_N' {
            local rid    = record_id[`i']
            local pname  = dq_name[`i']
            local visit  = dq_visit_label[`i']
            local vdate  = dq_visit_date[`i']
            local value  = string(_chg_glucose[`i'], "%9.1f")

            post dqpost ///
                ("C22") ///
                ("Review") ///
                ("Large glucose change") ///
                ("`rid'") ///
                ("`pname'") ///
                ("`visit'") ///
                ("`vdate'") ///
                ("glucose change") ///
                ("`value'") ///
                ("Check adjacent glucose values and dates")
        }
    restore
}


** -------------------------------------------------------------------------
** C23-C28. Withdrawal and adverse event safety fields
** -------------------------------------------------------------------------

** C23. Withdrawal date missing
capture confirm variable withdrawal_form_complete
if !_rc {
    preserve
        keep if has_pwd == 1 & missing(date_withdrawal)

        forvalues i = 1/`=_N' {
            local rid    = record_id[`i']
            local pname  = dq_name[`i']

            post dqpost ///
                ("C23") ///
                ("High") ///
                ("Withdrawal date missing") ///
                ("`rid'") ///
                ("`pname'") ///
                ("Withdrawal") ///
                ("Missing") ///
                ("date_withdrawal") ///
                ("Missing") ///
                ("Enter withdrawal date")
        }
    restore
}

** C24. Withdrawal reason missing
capture confirm variable reason_withdrawal
if !_rc {
    preserve
        keep if has_pwd == 1 & missing(reason_withdrawal)

        forvalues i = 1/`=_N' {
            local rid    = record_id[`i']
            local pname  = dq_name[`i']

            post dqpost ///
                ("C24") ///
                ("High") ///
                ("Withdrawal reason missing") ///
                ("`rid'") ///
                ("`pname'") ///
                ("Withdrawal") ///
                ("") ///
                ("reason_withdrawal") ///
                ("Missing") ///
                ("Enter withdrawal reason")
        }
    restore
}

** C25. Medical/adverse-effect withdrawal without AE report flag
capture confirm variable reason_withdrawal
local has_reason = !_rc
capture confirm variable ae_withdrawal_rpt
local has_ae_flag = !_rc

if `has_reason' == 1 & `has_ae_flag' == 1 {
    preserve
        keep if has_pwd == 1 & reason_withdrawal == 1 & missing(ae_withdrawal_rpt)

        forvalues i = 1/`=_N' {
            local rid    = record_id[`i']
            local pname  = dq_name[`i']

            post dqpost ///
                ("C25") ///
                ("High") ///
                ("Medical withdrawal AE flag missing") ///
                ("`rid'") ///
                ("`pname'") ///
                ("Withdrawal") ///
                ("") ///
                ("ae_withdrawal_rpt") ///
                ("Missing") ///
                ("Confirm whether adverse event was reported")
        }
    restore
}

** C26. Adverse event date missing
capture confirm variable date_ae
if !_rc {
    preserve
        keep if has_pae == 1 & missing(date_ae)

        forvalues i = 1/`=_N' {
            local rid    = record_id[`i']
            local pname  = dq_name[`i']

            post dqpost ///
                ("C26") ///
                ("High") ///
                ("AE date missing") ///
                ("`rid'") ///
                ("`pname'") ///
                ("Adverse event") ///
                ("Missing") ///
                ("date_ae") ///
                ("Missing") ///
                ("Enter adverse event date")
        }
    restore
}

** C27. Adverse event classification missing
capture confirm variable class_ae
if !_rc {
    preserve
        keep if has_pae == 1 & missing(class_ae)

        forvalues i = 1/`=_N' {
            local rid    = record_id[`i']
            local pname  = dq_name[`i']

            post dqpost ///
                ("C27") ///
                ("High") ///
                ("AE classification missing") ///
                ("`rid'") ///
                ("`pname'") ///
                ("Adverse event") ///
                ("") ///
                ("class_ae") ///
                ("Missing") ///
                ("Classify adverse event")
        }
    restore
}

** C28. Serious adverse event recorded
capture confirm variable class_ae
if !_rc {
    preserve
        keep if has_pae == 1 & class_ae == 2

        forvalues i = 1/`=_N' {
            local rid    = record_id[`i']
            local pname  = dq_name[`i']
            local adate  = ""

            capture confirm variable date_ae
            if !_rc {
                local adate = string(date_ae[`i'], "%tdDD/NN/CCYY")
            }

            post dqpost ///
                ("C28") ///
                ("High") ///
                ("Serious adverse event") ///
                ("`rid'") ///
                ("`pname'") ///
                ("Adverse event") ///
                ("`adate'") ///
                ("class_ae") ///
                ("SAE") ///
                ("Ensure SAE follow-up is complete")
        }
    restore
}

postclose dqpost


** =========================================================================
** PART 4. SUMMARISE DQ ISSUES
** =========================================================================

use `dq_issues', clear

count
local n_issues = r(N)

quietly count if severity == "High"
local n_high = r(N)

quietly count if severity == "Medium"
local n_medium = r(N)

quietly count if severity == "Review"
local n_review = r(N)


** -------------------------------------------------------------------------
** Count each individual check for Table 1
** -------------------------------------------------------------------------

quietly count if check_id == "C01"
local c_no_baseline = r(N)

quietly count if check_id == "C02"
local c_base_weight = r(N)

quietly count if check_id == "C03"
local c_base_hba1c = r(N)

quietly count if check_id == "C04"
local c_visit_date_missing = r(N)

quietly count if check_id == "C05"
local c_future_visit = r(N)

quietly count if check_id == "C06"
local c_visit_before_consent = r(N)

quietly count if check_id == "C07"
local c_negative_weeks = r(N)

quietly count if check_id == "C08"
local c_baseline_overdue = r(N)

quietly count if check_id == "C09"
local c_long_tmr_gap = r(N)

quietly count if check_id == "C10"
local c_implaus_weight = r(N)

quietly count if check_id == "C11"
local c_implaus_height = r(N)

quietly count if check_id == "C12"
local c_implaus_bmi = r(N)

quietly count if check_id == "C13"
local c_implaus_sbp = r(N)

quietly count if check_id == "C14"
local c_implaus_dbp = r(N)

quietly count if check_id == "C15"
local c_bp_logic = r(N)

quietly count if check_id == "C16"
local c_implaus_glucose = r(N)

quietly count if check_id == "C17"
local c_implaus_hba1c = r(N)

quietly count if check_id == "C18"
local c_implaus_egfr = r(N)

quietly count if check_id == "C19"
local c_large_weight = r(N)

quietly count if check_id == "C20"
local c_large_hba1c = r(N)

quietly count if check_id == "C21"
local c_large_sbp = r(N)

quietly count if check_id == "C22"
local c_large_glucose = r(N)

quietly count if check_id == "C23"
local c_withdrawal_date = r(N)

quietly count if check_id == "C24"
local c_withdrawal_reason = r(N)

quietly count if check_id == "C25"
local c_med_wd_ae_flag = r(N)

quietly count if check_id == "C26"
local c_ae_date = r(N)

quietly count if check_id == "C27"
local c_ae_class = r(N)

quietly count if check_id == "C28"
local c_sae = r(N)


** =========================================================================
** PART 5. CREATE WEEKLY DATA QUALITY PDF REPORT
** =========================================================================

putpdf clear
putpdf begin, pagesize(A4) ///
    margin(top, 0.5) margin(bottom, 0.5) ///
    margin(left, 0.5) margin(right, 0.5) ///
    font("Arial", 8)


** -------------------------------------------------------------------------
** Page title
** -------------------------------------------------------------------------

putpdf paragraph
putpdf text ("TMR Programme Data Quality Report"), bold font("Arial", 15)

putpdf paragraph
putpdf text ("Report date: `report_date'"), font("Arial", 9)

putpdf paragraph
putpdf text ("This weekly report highlights a minimal set of data quality checks for participants who have entered the TMR programme, focused on programme delivery, date logic, clinical plausibility, and safety/governance issues."), font("Arial", 8)

putpdf paragraph
putpdf text ("Dataset overview: `n_rows' rows from `n_participants' programme entrants. All screening-only participants are excluded. `n_baseline' participants have a recorded baseline date."), font("Arial", 8)


** -------------------------------------------------------------------------
** Table 1. Summary of all checks made
** -------------------------------------------------------------------------

putpdf paragraph
putpdf text ("1. Summary of checks made"), bold font("Arial", 12)

putpdf paragraph
putpdf text ("This table lists every active check in the weekly DQ report. The count is the number of records or rows with a potential issue for that check. A zero means the check was run and no potential issue was found."), font("Arial", 8)

putpdf table summary = (29,2), width(100%) border(all, single)

putpdf table summary(1,1) = ("Check made")
putpdf table summary(1,2) = ("Records/rows flagged")

putpdf table summary(2,1) = ("C01. Programme entrant has no baseline visit (cohort integrity check; should be zero)")
putpdf table summary(2,2) = ("`c_no_baseline'")

putpdf table summary(3,1) = ("C02. Baseline visit exists but baseline weight is missing")
putpdf table summary(3,2) = ("`c_base_weight'")

putpdf table summary(4,1) = ("C03. Baseline visit exists but baseline HbA1c is missing from both HbA1c sources")
putpdf table summary(4,2) = ("`c_base_hba1c'")

putpdf table summary(5,1) = ("C04. Programme measurement row has no programme visit date")
putpdf table summary(5,2) = ("`c_visit_date_missing'")

putpdf table summary(6,1) = ("C05. Programme visit date is later than the report date")
putpdf table summary(6,2) = ("`c_future_visit'")

putpdf table summary(7,1) = ("C06. Programme visit date is before the recorded consent date")
putpdf table summary(7,2) = ("`c_visit_before_consent'")

putpdf table summary(8,1) = ("C07. Weeks from baseline is negative")
putpdf table summary(8,2) = ("`c_negative_weeks'")

putpdf table summary(9,1) = ("C08. Participant is baseline-only and more than 21 days have elapsed since baseline")
putpdf table summary(9,2) = ("`c_baseline_overdue'")

putpdf table summary(10,1) = ("C09. TMR phase gap between consecutive visits is greater than 21 days")
putpdf table summary(10,2) = ("`c_long_tmr_gap'")

putpdf table summary(11,1) = ("C10. Weight is outside the plausibility range 40 to 200 kg")
putpdf table summary(11,2) = ("`c_implaus_weight'")

putpdf table summary(12,1) = ("C11. Height is outside the plausibility range 120 to 220 cm")
putpdf table summary(12,2) = ("`c_implaus_height'")

putpdf table summary(13,1) = ("C12. Screening BMI is outside the plausibility range 15 to 70")
putpdf table summary(13,2) = ("`c_implaus_bmi'")

putpdf table summary(14,1) = ("C13. Systolic blood pressure is outside the plausibility range 70 to 250 mmHg")
putpdf table summary(14,2) = ("`c_implaus_sbp'")

putpdf table summary(15,1) = ("C14. Diastolic blood pressure is outside the plausibility range 40 to 150 mmHg")
putpdf table summary(15,2) = ("`c_implaus_dbp'")

putpdf table summary(16,1) = ("C15. Diastolic blood pressure is greater than or equal to systolic blood pressure")
putpdf table summary(16,2) = ("`c_bp_logic'")

putpdf table summary(17,1) = ("C16. Glucose is outside the plausibility range 2 to 35 mmol/L")
putpdf table summary(17,2) = ("`c_implaus_glucose'")

putpdf table summary(18,1) = ("C17. HbA1c is outside the plausibility range 20 to 160 mmol/mol")
putpdf table summary(18,2) = ("`c_implaus_hba1c'")

putpdf table summary(19,1) = ("C18. eGFR is outside the plausibility range 0 to 150")
putpdf table summary(19,2) = ("`c_implaus_egfr'")

putpdf table summary(20,1) = ("C19. Weight changes by more than 7 kg between consecutive dated programme rows")
putpdf table summary(20,2) = ("`c_large_weight'")

putpdf table summary(21,1) = ("C20. HbA1c changes by more than 30 mmol/mol between consecutive dated programme rows")
putpdf table summary(21,2) = ("`c_large_hba1c'")

putpdf table summary(22,1) = ("C21. Average systolic BP changes by more than 50 mmHg between consecutive dated programme rows")
putpdf table summary(22,2) = ("`c_large_sbp'")

putpdf table summary(23,1) = ("C22. Glucose changes by more than 15 mmol/L between consecutive dated programme rows")
putpdf table summary(23,2) = ("`c_large_glucose'")

putpdf table summary(24,1) = ("C23. Withdrawal form exists but withdrawal date is missing")
putpdf table summary(24,2) = ("`c_withdrawal_date'")

putpdf table summary(25,1) = ("C24. Withdrawal form exists but withdrawal reason is missing")
putpdf table summary(25,2) = ("`c_withdrawal_reason'")

putpdf table summary(26,1) = ("C25. Medical or adverse-effect withdrawal has missing adverse-event report flag")
putpdf table summary(26,2) = ("`c_med_wd_ae_flag'")

putpdf table summary(27,1) = ("C26. Adverse event form exists but adverse event date is missing")
putpdf table summary(27,2) = ("`c_ae_date'")

putpdf table summary(28,1) = ("C27. Adverse event form exists but classification is missing")
putpdf table summary(28,2) = ("`c_ae_class'")

putpdf table summary(29,1) = ("C28. Serious adverse event recorded")
putpdf table summary(29,2) = ("`c_sae'")

putpdf table summary(.,.), font("Arial", 7)
putpdf table summary(1,.), bold


** -------------------------------------------------------------------------
** Table 2. Current programme phase
** -------------------------------------------------------------------------

putpdf pagebreak
putpdf paragraph
putpdf text ("2. Current programme phase"), bold font("Arial", 12)

putpdf paragraph
putpdf text ("This table gives a simple operational view of where participants currently appear to be in the programme, based on each participant's latest derived programme visit number."), font("Arial", 8)

putpdf table phase = (7,2), width(70%) border(all, single)

putpdf table phase(1,1) = ("Current phase")
putpdf table phase(1,2) = ("Participants")

putpdf table phase(2,1) = ("Baseline only")
putpdf table phase(2,2) = ("`n_current_baseline'")

putpdf table phase(3,1) = ("TMR phase")
putpdf table phase(3,2) = ("`n_current_tmr'")

putpdf table phase(4,1) = ("Food reintroduction phase")
putpdf table phase(4,2) = ("`n_current_food'")

putpdf table phase(5,1) = ("Year 1 maintenance phase")
putpdf table phase(5,2) = ("`n_current_year1'")

putpdf table phase(6,1) = ("Year 2 maintenance phase")
putpdf table phase(6,2) = ("`n_current_year2'")

putpdf table phase(7,1) = ("Beyond planned structure")
putpdf table phase(7,2) = ("`n_current_extra'")

putpdf table phase(.,.), font("Arial", 8)
putpdf table phase(1,.), bold


** -------------------------------------------------------------------------
** Table 3. DQ issue counts by severity
** -------------------------------------------------------------------------

putpdf paragraph
putpdf text ("3. Data quality flags by severity"), bold font("Arial", 12)

putpdf paragraph
putpdf text ("This table summarises all generated DQ flags by severity. High-priority flags are those most likely to affect governance, participant safety, programme delivery, or primary monitoring outputs."), font("Arial", 8)

putpdf table sevtab = (4,2), width(60%) border(all, single)

putpdf table sevtab(1,1) = ("Severity")
putpdf table sevtab(1,2) = ("Flags")

putpdf table sevtab(2,1) = ("High")
putpdf table sevtab(2,2) = ("`n_high'")

putpdf table sevtab(3,1) = ("Medium")
putpdf table sevtab(3,2) = ("`n_medium'")

putpdf table sevtab(4,1) = ("Review")
putpdf table sevtab(4,2) = ("`n_review'")

putpdf table sevtab(.,.), font("Arial", 8)
putpdf table sevtab(1,.), bold


** -------------------------------------------------------------------------
** Table 4. Issue counts by issue type
** -------------------------------------------------------------------------

putpdf paragraph
putpdf text ("4. Data quality flags by issue type"), bold font("Arial", 12)

putpdf paragraph
putpdf text ("This table groups the generated DQ flags by issue type. It helps identify whether problems are concentrated in dates, visit scheduling, clinical values, or safety/governance fields."), font("Arial", 8)

if `n_issues' > 0 {

    preserve
        contract issue, freq(n)
        gsort -n issue

        local n_issue_types = _N
        local n_issue_rows = min(`n_issue_types', 20)
        local pdf_rows = `n_issue_rows' + 1

        putpdf table issuetypes = (`pdf_rows',2), width(100%) border(all, single)

        putpdf table issuetypes(1,1) = ("Issue")
        putpdf table issuetypes(1,2) = ("Flags")

        forvalues i = 1/`n_issue_rows' {
            local row = `i' + 1
            local issue_txt = issue[`i']
            local n_txt = string(n[`i'], "%9.0f")

            putpdf table issuetypes(`row',1) = ("`issue_txt'")
            putpdf table issuetypes(`row',2) = ("`n_txt'")
        }

        putpdf table issuetypes(.,.), font("Arial", 7)
        putpdf table issuetypes(1,.), bold
    restore
}
else {
    putpdf paragraph
    putpdf text ("No data quality flags were generated by the minimal weekly checks."), font("Arial", 8)
}


** -------------------------------------------------------------------------
** Table 5. Detailed issue register
** -------------------------------------------------------------------------

putpdf pagebreak

putpdf paragraph
putpdf text ("5. Detailed data quality review list"), bold font("Arial", 12)

putpdf paragraph
putpdf text ("This table lists individual records or rows requiring review. IDs are displayed in their original format, but sorted using a numeric ID key created by removing the dash, so 305-1 is sorted as 3051 while still being shown as 305-1."), font("Arial", 8)

if `n_issues' > 0 {

    ** Create numeric sort key from record_id.
    ** Example: 305-1 becomes 3051 for sorting only.
    ** The original record_id is still displayed in the report.
    gen str40 id_sort_str = subinstr(strtrim(record_id), "-", "", .)
    gen double id_sort_num = real(id_sort_str)
    gen byte id_sort_missing = missing(id_sort_num)

    sort id_sort_missing id_sort_num record_id check_id visit_date issue

    local max_show = min(`n_issues', 60)
    local detail_rows = `max_show' + 1

    putpdf table details = (`detail_rows',10), width(100%) border(all, single)

    putpdf table details(1,1) = ("Check")
    putpdf table details(1,2) = ("Severity")
    putpdf table details(1,3) = ("Issue")
    putpdf table details(1,4) = ("ID")
    putpdf table details(1,5) = ("Name")
    putpdf table details(1,6) = ("Visit")
    putpdf table details(1,7) = ("Date")
    putpdf table details(1,8) = ("Variable")
    putpdf table details(1,9) = ("Value")
    putpdf table details(1,10) = ("Suggested action")

    forvalues i = 1/`max_show' {

        local row = `i' + 1

        local check_txt  = check_id[`i']
        local sev_txt    = severity[`i']
        local issue_txt  = issue[`i']
        local rid_txt    = record_id[`i']
        local name_txt   = name[`i']
        local visit_txt  = visit[`i']
        local date_txt   = visit_date[`i']
        local var_txt    = variable[`i']
        local value_txt  = value[`i']
        local action_txt = action[`i']

        putpdf table details(`row',1) = ("`check_txt'")
        putpdf table details(`row',2) = ("`sev_txt'")
        putpdf table details(`row',3) = ("`issue_txt'")
        putpdf table details(`row',4) = ("`rid_txt'")
        putpdf table details(`row',5) = ("`name_txt'")
        putpdf table details(`row',6) = ("`visit_txt'")
        putpdf table details(`row',7) = ("`date_txt'")
        putpdf table details(`row',8) = ("`var_txt'")
        putpdf table details(`row',9) = ("`value_txt'")
        putpdf table details(`row',10) = ("`action_txt'")
    }

    putpdf table details(.,.), font("Arial", 5)
    putpdf table details(1,.), bold
}
else {
    putpdf paragraph
    putpdf text ("No detailed issues to list."), font("Arial", 8)
}


** -------------------------------------------------------------------------
** Appendix: possible additional checks
** -------------------------------------------------------------------------

putpdf pagebreak

putpdf paragraph
putpdf text ("Appendix. Possible additional checks to add later"), bold font("Arial", 12)

putpdf paragraph
putpdf text ("These checks are not included in the minimal weekly report. They can be added later if the team decides they are useful and not too noisy."), font("Arial", 8)

putpdf table optional = (11,2), width(100%) border(all, single)

putpdf table optional(1,1) = ("Optional check")
putpdf table optional(1,2) = ("Why it might be useful")

putpdf table optional(2,1) = ("Same EMIS ID linked to more than one record_id")
putpdf table optional(2,2) = ("Possible duplicate participant records")

putpdf table optional(3,1) = ("Multiple EMIS IDs within one record_id")
putpdf table optional(3,2) = ("Possible participant mismatch or data entry issue")

putpdf table optional(4,1) = ("Screening DOB/sex differs from programme DOB/sex")
putpdf table optional(4,2) = ("Cross-form identity consistency check")

putpdf table optional(5,1) = ("Rows with data but REDCap form marked incomplete")
putpdf table optional(5,2) = ("Workflow and form completion quality")

putpdf table optional(6,1) = ("Rows marked complete but key fields missing")
putpdf table optional(6,2) = ("Completion status may not reflect usable data")

putpdf table optional(7,1) = ("Food phase gap greater than 35 days")
putpdf table optional(7,2) = ("Delayed food reintroduction follow-up")

putpdf table optional(8,1) = ("Maintenance phase gap greater than 120 days")
putpdf table optional(8,2) = ("Delayed longer-term follow-up")

putpdf table optional(9,1) = ("Full laboratory plausibility checks")
putpdf table optional(9,2) = ("Useful later, but may be too noisy initially")

putpdf table optional(10,1) = ("Medication status change alerts")
putpdf table optional(10,2) = ("Could support clinical review during TMR phase")

putpdf table optional(11,1) = ("Missingness matrix by visit")
putpdf table optional(11,2) = ("Useful for monitoring completeness across outcome domains")

putpdf table optional(.,.), font("Arial", 7)
putpdf table optional(1,.), bold


** -------------------------------------------------------------------------
** Save PDF
** -------------------------------------------------------------------------

putpdf save "$pdfdir\tmr_dq_report_`report_date_file'.pdf", replace

di as result "Weekly TMR data quality PDF report saved:"
di as result "$pdfdir\tmr_dq_report_`report_date_file'.pdf"

capture log close
