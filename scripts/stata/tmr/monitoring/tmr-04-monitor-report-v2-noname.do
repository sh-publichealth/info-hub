** HEADER -----------------------------------------------------
**  DO-FILE METADATA
    //  algorithm name             tmr-04-monitor-report-v2.do
    //  project:                   SH007 total meal replacement
    //  analysts:                  Ian HAMBLETON
    //  date last modified         14-Aug-2026
    //  workflow step              4 of 4
    //  algorithm task             Create the TMR monitoring PDF report from
    //                              the shared prepared dataset, including
    //                              recruitment and retention metrics; individual
    //                              outcome pages include programme starters only

    ** General algorithm set-up
    version 19
    clear all
    macro drop _all
    set more off
    set linesize 80

    ** Folder locations
    global projectroot "C:\yoshimi-hot\output\analyse-sth\sh007-total-meal-replacement\stata"
    global rawdir      "$projectroot/data_raw"
    global cleandir    "$projectroot/data_clean"
    global outputdir   "$projectroot/output"
    global figdir      "$projectroot/output/figures"
    global pdfdir      "$projectroot/output/pdf"
    global log         "$projectroot/logs"

    ** Create output folders if they do not already exist
    capture mkdir "$outputdir"
    capture mkdir "$figdir"
    capture mkdir "$pdfdir"
    capture mkdir "$log"

    ** Close any open log file and open a new log file
    capture log close
    log using "$log\tmr-04-monitor-report", replace
** HEADER -----------------------------------------------------


** -------------------------------------------------------------------------
** Load the shared analysis-prepared dataset
**
** This dataset is created by:
**
**     tmr-02-prepare-data.do
**
** The monitoring report uses programme measurement rows only. Two local
** compatibility variables are created because the report was originally
** written against the earlier monitoring-only prepared dataset:
**
**     visit_number        <- prog_visit_num
**     baseline_visit_date <- baseline_prog_date
**
** No separate tmr_monitor_001.dta dataset is required.
**
** Recruitment/screening summaries deliberately include the wider screened
** population. Group outcome summaries, graphs and individual participant
** pages are restricted to people who have actually started the programme,
** operationally defined by a recorded baseline programme visit.
** -------------------------------------------------------------------------

local analysis_dta "$cleandir\tmr_full_analysis_dataset_latest.dta"

capture confirm file "`analysis_dta'"
if _rc {
    di as error "The shared analysis-prepared dataset was not found:"
    di as error "`analysis_dta'"
    di as error "Run tmr-01-redcap-extract.do and then tmr-02-prepare-data.do."
    exit 601
}

use "`analysis_dta'", clear

capture confirm variable has_pmeas
if _rc {
    di as error "Variable has_pmeas was not found in the prepared dataset."
    di as error "Re-run tmr-02-prepare-data.do before creating this report."
    exit 111
}

keep if has_pmeas == 1

capture confirm variable prog_visit_num
if _rc {
    di as error "Variable prog_visit_num was not found in the prepared dataset."
    exit 111
}

capture confirm variable baseline_prog_date
if _rc {
    di as error "Variable baseline_prog_date was not found in the prepared dataset."
    exit 111
}

capture drop visit_number
gen visit_number = prog_visit_num
label variable visit_number "Monitoring report: planned programme visit number"

capture drop baseline_visit_date
gen baseline_visit_date = baseline_prog_date
format baseline_visit_date %dM_d,_CY
label variable baseline_visit_date "Monitoring report: baseline programme date"

label data "TMR monitoring report input dataset"


** -------------------------------------------------------------------------
** Add participant recruitment and programme-status fields
**
** The REDCap extraction do-file creates one stable, participant-level dataset:
**
**     tmr_monitor_participant_status.dta
**
** It contains screening, eligibility, interest, site and completed
** withdrawal information. The existing outcome dataset remains the master
** dataset. Only matching status values are added to its longitudinal rows.
**
** Recruitment counts are calculated separately from the participant-level
** file later in this do-file. This is essential because people who were
** screened but did not start the programme do not appear in the outcome
** dataset.
** -------------------------------------------------------------------------

local status_dta "$cleandir\tmr_monitor_participant_status.dta"

capture confirm file "`status_dta'"

if _rc {
    di as error "The participant recruitment/status dataset was not found:"
    di as error "`status_dta'"
    di as error "Run tmr-01-redcap-extract.do before this report."
    exit 601
}

merge m:1 record_id using "`status_dta'", ///
    keep(master match) ///
    keepusing( ///
        screened ///
        eligible ///
        interest_status ///
        withdrawn ///
        withdrawal_date ///
    )

rename _merge status_merge_result

label variable status_merge_result ///
    "Match to participant recruitment/status dataset"

quietly count if status_merge_result == 1

if r(N) > 0 {
    di as error "WARNING: outcome rows without a matching participant status record: " r(N)
}


sort record_id visit_date_cm

** -------------------------------------------------------------------------
** Create a stable numeric participant counter for looping
** -------------------------------------------------------------------------

egen pid = group(record_id), label

capture confirm string variable record_id
if _rc {
    gen str30 record_id_str = string(record_id, "%12.0g")
}
else {
    gen str30 record_id_str = record_id
}

label variable pid "Internal numeric participant counter"
label variable record_id_str "Participant Study ID as string"


** -------------------------------------------------------------------------
** SITE DERIVED FROM STUDY ID
**
** Use the study ID prefix as the authoritative site definition throughout
** this report:
**
**     305 = St Helena
**     306 = Ascension
**
** This avoids relying on a later REDCap site field, which may be missing for
** people at earlier stages of the pathway.
** -------------------------------------------------------------------------

gen byte site_sth_id = ///
    substr(record_id_str, 1, 3) == "305"

gen byte site_asc_id = ///
    substr(record_id_str, 1, 3) == "306"

label variable site_sth_id ///
    "St Helena site from study ID prefix 305"

label variable site_asc_id ///
    "Ascension site from study ID prefix 306"

quietly count if ///
    site_sth_id == 0 & ///
    site_asc_id == 0

if r(N) > 0 {
    di as error ///
        "WARNING: outcome rows with study ID prefix other than 305 or 306: " r(N)
}


** -------------------------------------------------------------------------
** Ensure HbA1c variables exist for reporting
**
** hba1c exists in the prepared dataset, but may currently be empty.
** This section creates baseline and change variables for HbA1c so that the
** report structure is ready once values start to appear.
** -------------------------------------------------------------------------

capture confirm variable hba1c
if _rc {
    gen hba1c = .
    label variable hba1c "HbA1c (mmol/mol)"
}

capture confirm variable baseline_hba1c
if _rc {

    bysort record_id: egen baseline_hba1c_date = min(cond(!missing(hba1c), visit_date_cm, .))
    format baseline_hba1c_date %dM_d,_CY
    label variable baseline_hba1c_date "Date of baseline HbA1c"

    gen _baseline_hba1c = hba1c if visit_date_cm == baseline_hba1c_date & !missing(hba1c)
    bysort record_id: egen baseline_hba1c = max(_baseline_hba1c)
    drop _baseline_hba1c

    label variable baseline_hba1c "Baseline HbA1c (mmol/mol)"
}

capture confirm variable change_hba1c_abs
if _rc {
    gen change_hba1c_abs = hba1c - baseline_hba1c
    label variable change_hba1c_abs "Absolute change in HbA1c from baseline (mmol/mol)"
}

capture confirm variable change_hba1c_pct
if _rc {
    gen change_hba1c_pct = 100 * (hba1c - baseline_hba1c) / baseline_hba1c if baseline_hba1c > 0
    label variable change_hba1c_pct "Percentage change in HbA1c from baseline"
}


** -------------------------------------------------------------------------
** Create report date local
** -------------------------------------------------------------------------

local report_date = "`c(current_date)'"
local report_date_file = subinstr("`c(current_date)'", " ", "_", .)


** -------------------------------------------------------------------------
** Standard visit row labels for PDF tables
**
** These rows are used for both the group page and each participant page.
** The mapping is currently based on visit_number in the prepared dataset:
**
**     visit_number 1  = Baseline
**     visit_number 2  = TMR visit 1
**     visit_number 3  = TMR visit 2
**     ...
**     visit_number 15 = Year 1 weight visit 4
** -------------------------------------------------------------------------

local n_report_rows = 15

local rowlabel1  "Baseline"
local rowlabel2  "TMR visit 1"
local rowlabel3  "TMR visit 2"
local rowlabel4  "TMR visit 3"
local rowlabel5  "TMR visit 4"
local rowlabel6  "TMR visit 5"
local rowlabel7  "TMR visit 6"
local rowlabel8  "Food visit 1"
local rowlabel9  "Food visit 2"
local rowlabel10 "Food visit 3"
local rowlabel11 "Food visit 4"
local rowlabel12 "Year 1 weight visit 1"
local rowlabel13 "Year 1 weight visit 2"
local rowlabel14 "Year 1 weight visit 3"
local rowlabel15 "Year 1 weight visit 4"


** -------------------------------------------------------------------------
** Recruitment and screening counts
**
** These counts are calculated from the one-row-per-person status dataset,
** not from the outcome dataset. The distinction matters because screened
** people who did not enter the programme have no outcome rows.
** -------------------------------------------------------------------------

preserve

    use "`status_dta'", clear

    quietly count if screened == 1
    local n_screened = r(N)

    quietly count if eligible == 1
    local n_eligible = r(N)

    quietly count if ///
        eligible == 1 & ///
        interest_status == 1
    local n_interested = r(N)

    quietly count if ///
        eligible == 1 & ///
        interest_status == 2
    local n_not_interested = r(N)

    quietly count if ///
        eligible == 1 & ///
        interest_status == 3
    local n_decision_pending = r(N)

    quietly count if ///
        eligible == 1 & ///
        missing(interest_status)
    local n_interest_missing = r(N)


    ** ---------------------------------------------------------------------
    ** St Helena-only recruitment and screening counts
    **
    ** Site is derived directly from the study ID prefix:
    **
    **     305 = St Helena
    **     306 = Ascension
    **
    ** The five overall counts above are left completely unchanged.
    ** ---------------------------------------------------------------------

    capture confirm string variable record_id

    if _rc {
        di as error "record_id is not a string in the participant status dataset."
        di as error "Cannot derive site safely from the 305/306 study ID prefix."
        restore
        exit 109
    }

    gen byte site_sth_id = ///
        substr(record_id, 1, 3) == "305"

    gen byte site_asc_id = ///
        substr(record_id, 1, 3) == "306"

    quietly count if ///
        site_sth_id == 0 & ///
        site_asc_id == 0

    if r(N) > 0 {
        di as error ///
            "WARNING: status records with study ID prefix other than 305 or 306: " r(N)
    }

    quietly count if ///
        screened == 1 & ///
        site_sth_id == 1
    local n_screened_sth = r(N)

    quietly count if ///
        eligible == 1 & ///
        site_sth_id == 1
    local n_eligible_sth = r(N)

    quietly count if ///
        eligible == 1 & ///
        interest_status == 1 & ///
        site_sth_id == 1
    local n_interested_sth = r(N)

    quietly count if ///
        eligible == 1 & ///
        interest_status == 2 & ///
        site_sth_id == 1
    local n_not_interested_sth = r(N)

    quietly count if ///
        eligible == 1 & ///
        interest_status == 3 & ///
        site_sth_id == 1
    local n_decision_pending_sth = r(N)

restore


** -------------------------------------------------------------------------
** Programme participation and retention
**
** The outcome dataset contains one or more longitudinal rows per programme
** participant. We therefore create a participant tag and count each person
** once.
**
** STARTED PROGRAMME
**
** A participant has started when baseline_visit_date is non-missing.
**
** WITHDRAWN
**
** The participant-level status file defines withdrawal using a completed
** REDCap withdrawal form. This is the agreed stronger definition.
**
** ACTIVE
**
** An active participant has started the programme and does not have a
** completed withdrawal form.
** -------------------------------------------------------------------------

egen byte participant_tag = tag(record_id)

** -------------------------------------------------------------------------
** STARTED PROGRAMME
**
** baseline_visit_date is longitudinal data and need not be populated on the
** same row selected by participant_tag. We therefore establish programme
** start across ALL rows for each participant before counting people.
** -------------------------------------------------------------------------

gen byte started_programme_row = ///
    !missing(baseline_visit_date)

bysort record_id: egen byte started_programme = ///
    max(started_programme_row)

drop started_programme_row

label variable started_programme ///
    "Participant has at least one baseline visit"

** Outcome monitoring should include only people who have entered the study.
** The recruitment table above remains intentionally broader and continues to
** describe screened, eligible, interested, not-interested and pending people.
gen byte include_outcome_monitoring = started_programme == 1
label variable include_outcome_monitoring ///
    "Include in group and individual outcome monitoring"

gen byte active_programme = ///
    started_programme == 1 & ///
    withdrawn == 0

label variable active_programme ///
    "Started programme and no completed withdrawal form"


** -------------------------------------------------------------------------
** Find the visit after which withdrawal occurred
**
** For each withdrawn participant:
**
**     1. identify visits dated on or before the withdrawal date;
**     2. take the largest planned visit number among those visits;
**     3. carry that visit number across all rows for the participant.
**
** A missing result means that the participant has a completed withdrawal
** form but no dated programme visit on or before the withdrawal date.
** -------------------------------------------------------------------------

gen byte visit_before_withdrawal = ///
    visit_number ///
    if withdrawn == 1 ///
    & !missing(withdrawal_date) ///
    & !missing(visit_date_cm) ///
    & visit_date_cm <= withdrawal_date

bysort record_id: egen byte withdrawal_after_visit = ///
    max(visit_before_withdrawal)

label variable withdrawal_after_visit ///
    "Latest planned visit on or before withdrawal"

drop visit_before_withdrawal


** -------------------------------------------------------------------------
** Count programme starters, withdrawals and active participants
** -------------------------------------------------------------------------

quietly count if ///
    participant_tag == 1 & ///
    started_programme == 1
local n_started = r(N)

quietly count if ///
    participant_tag == 1 & ///
    started_programme == 1 & ///
    withdrawn == 1
local n_withdrawn = r(N)

di as result "Withdrawn participants included in monitoring report:"

list record_id if ///
    participant_tag == 1 & ///
    started_programme == 1 & ///
    withdrawn == 1, ///
    noobs

quietly count if ///
    participant_tag == 1 & ///
    active_programme == 1
local n_active = r(N)

quietly count if ///
    participant_tag == 1 & ///
    active_programme == 1 & ///
    site_sth_id == 1
local n_active_sth = r(N)

quietly count if ///
    participant_tag == 1 & ///
    active_programme == 1 & ///
    site_asc_id == 1
local n_active_asc = r(N)

quietly count if ///
    participant_tag == 1 & ///
    active_programme == 1 & ///
    site_sth_id == 0 & ///
    site_asc_id == 0
local n_active_site_missing = r(N)


** -------------------------------------------------------------------------
** Programme-status consistency checks
**
** These checks print visible warnings. They do not alter the existing report
** calculations or stop the report merely because operational data need
** attention.
** -------------------------------------------------------------------------

if `n_active' + `n_withdrawn' != `n_started' {
    di as error "WARNING: active plus withdrawn does not equal programme starters."
    di as error "Started: `n_started'; active: `n_active'; withdrawn: `n_withdrawn'"
}

if `n_active_sth' + `n_active_asc' + `n_active_site_missing' != `n_active' {
    di as error "WARNING: active site counts do not add to the active total."
}

if `n_active_site_missing' > 0 {
    di as error "WARNING: active participants with missing study site: `n_active_site_missing'"
}

quietly count if ///
    participant_tag == 1 & ///
    withdrawn == 1 & ///
    missing(withdrawal_date)

if r(N) > 0 {
    di as error "WARNING: withdrawn participants with a missing withdrawal date: " r(N)
}

quietly count if ///
    participant_tag == 1 & ///
    withdrawn == 1 & ///
    !missing(withdrawal_date) & ///
    missing(withdrawal_after_visit)

if r(N) > 0 {
    di as error "WARNING: withdrawals with no dated visit on or before withdrawal: " r(N)
}

quietly count if ///
    withdrawn == 1 & ///
    !missing(withdrawal_date) & ///
    !missing(visit_date_cm) & ///
    visit_date_cm > withdrawal_date

if r(N) > 0 {
    di as error "WARNING: outcome rows dated after a participant withdrawal date: " r(N)
}

if `n_interest_missing' > 0 {
    di as error "WARNING: in-person eligible people with no final interest response: `n_interest_missing'"
}


** -------------------------------------------------------------------------
** Display the new monitoring totals in the Stata log
** -------------------------------------------------------------------------

di as result "Recruitment and screening summary"
di as result "  Screened: `n_screened'"
di as result "  Eligible: `n_eligible'"
di as result "  Eligible and interested: `n_interested'"
di as result "  Eligible and not interested: `n_not_interested'"
di as result "  Eligible with decision pending: `n_decision_pending'"

di as result "Programme participation and retention summary"
di as result "  Started programme: `n_started'"
di as result "  Active: `n_active'"
di as result "  Withdrawn: `n_withdrawn'"
di as result "  Active in St Helena: `n_active_sth'"
di as result "  Active in Ascension: `n_active_asc'"


** -------------------------------------------------------------------------
** STRICT OUTCOME-MONITORING COHORT FILTER
**
** From this point onwards the working dataset contains ONLY participants
** who have actually entered the programme, defined by a recorded baseline
** programme visit. Screening-only records remain represented in the
** recruitment summary above, but cannot enter group outcomes or individual
** participant pages below.
** -------------------------------------------------------------------------

keep if include_outcome_monitoring == 1

quietly count if participant_tag == 1
local n_monitoring_cohort = r(N)

di as result "Outcome monitoring cohort retained after strict filter: `n_monitoring_cohort' participants"

if `n_monitoring_cohort' != `n_started' {
    di as error "ERROR: strict monitoring cohort does not equal the number of programme starters."
    di as error "Started: `n_started'; retained: `n_monitoring_cohort'"
    exit 459
}


** -------------------------------------------------------------------------
** Percentage text for headline recruitment indicators
**
** Both percentages use the number screened as their denominator:
**
**     Eligible percentage = eligible / screened
**     Started percentage  = started  / screened
**
** Display percentages as whole numbers to keep the page-one summary compact.
** If the screened count is zero, leave the percentage text blank.
** -------------------------------------------------------------------------

local eligible_display "`n_eligible'"
local started_display  "`n_started'"

if `n_screened' > 0 {

    local eligible_pct = 100 * `n_eligible' / `n_screened'
    local started_pct  = 100 * `n_started'  / `n_screened'

    local eligible_pct_txt : display %3.0f `eligible_pct'
    local started_pct_txt  : display %3.0f `started_pct'

    local eligible_pct_txt = trim("`eligible_pct_txt'")
    local started_pct_txt  = trim("`started_pct_txt'")

    local eligible_display "`n_eligible' (`eligible_pct_txt'% of screened)"
    local started_display  "`n_started' (`started_pct_txt'% of screened)"
}


** -------------------------------------------------------------------------
** Additional display percentages for Table 1
**
** These are display-only additions. Counts are unchanged.
** -------------------------------------------------------------------------

local interested_display "`n_interested'"
local eligible_sth_display "`n_eligible_sth'"
local interested_sth_display "`n_interested_sth'"

if `n_screened' > 0 {

    local interested_pct = ///
        100 * `n_interested' / `n_screened'

    local interested_pct_txt : ///
        display %3.0f `interested_pct'

    local interested_pct_txt = ///
        trim("`interested_pct_txt'")

    local interested_display ///
        "`n_interested' (`interested_pct_txt'% of screened)"
}

if `n_screened_sth' > 0 {

    local eligible_sth_pct = ///
        100 * `n_eligible_sth' / `n_screened_sth'

    local interested_sth_pct = ///
        100 * `n_interested_sth' / `n_screened_sth'

    local eligible_sth_pct_txt : ///
        display %3.0f `eligible_sth_pct'

    local interested_sth_pct_txt : ///
        display %3.0f `interested_sth_pct'

    local eligible_sth_pct_txt = ///
        trim("`eligible_sth_pct_txt'")

    local interested_sth_pct_txt = ///
        trim("`interested_sth_pct_txt'")

    local eligible_sth_display ///
        "`n_eligible_sth' (`eligible_sth_pct_txt'% of screened)"

    local interested_sth_display ///
        "`n_interested_sth' (`interested_sth_pct_txt'% of screened)"
}



** -------------------------------------------------------------------------
** Create group average line charts
**
** Two graphs are created:
**     1. Mean weight change from baseline
**     2. Mean HbA1c change from baseline
**
** HbA1c is expected to be empty for now. A placeholder graph is generated
** with a sensible y-axis range for future HbA1c change values.
** -------------------------------------------------------------------------

preserve

    ** Outcome graphs are for programme starters only.
    keep if include_outcome_monitoring == 1

    collapse ///
        (mean) mean_change_weight_abs = change_weight_abs ///
               mean_change_hba1c_abs = change_hba1c_abs ///
        (count) n_weight = change_weight_abs ///
                n_hba1c = change_hba1c_abs, ///
        by(weeks_from_baseline)

    sort weeks_from_baseline


    ** Group weight graph
    count if !missing(mean_change_weight_abs) & !missing(weeks_from_baseline)

    if r(N) > 0 {
        twoway ///
            (connected mean_change_weight_abs weeks_from_baseline if !missing(mean_change_weight_abs), ///
                msymbol(circle) msize(medium) lwidth(medthick)), ///
            title("Weight", size(medsmall)) ///
            xtitle("Weeks from baseline", size(small)) ///
            ytitle("Mean change, kg", size(small)) ///
            xlabel(, labsize(small)) ///
            ylabel(, labsize(small)) ///
            yline(0) ///
            legend(order(1 "Weight") pos(12) ring(0) cols(1) size(small)) ///
            xsize(6.2) ysize(3.8) ///
            name(group_weight_change, replace)
    }
    else {
        twoway scatteri 0 0, ///
            msymbol(none) ///
            title("Weight", size(medsmall)) ///
            subtitle("No available data", size(small)) ///
            xtitle("Weeks from baseline", size(small)) ///
            ytitle("Mean change, kg", size(small)) ///
            xlabel(, labsize(small)) ///
            ylabel(, labsize(small)) ///
            yline(0) ///
            legend(off) ///
            xsize(6.2) ysize(3.8) ///
            name(group_weight_change, replace)
    }

    graph export "$figdir\group_weight_change_abs.png", replace width(1700)


    ** Group HbA1c graph
    count if !missing(mean_change_hba1c_abs) & !missing(weeks_from_baseline)

    if r(N) > 0 {
        twoway ///
            (connected mean_change_hba1c_abs weeks_from_baseline if !missing(mean_change_hba1c_abs), ///
                msymbol(circle) msize(medium) lwidth(medthick)), ///
            title("HbA1c", size(medsmall)) ///
            xtitle("Weeks from baseline", size(small)) ///
            ytitle("Mean change, mmol/mol", size(small)) ///
            xlabel(, labsize(small)) ///
            ylabel(-40(10)20, labsize(small)) ///
            yline(0) ///
            yscale(range(-40 20)) ///
            legend(order(1 "HbA1c") pos(12) ring(0) cols(1) size(small)) ///
            xsize(6.2) ysize(3.8) ///
            name(group_hba1c_change, replace)
    }
    else {
        twoway scatteri 0 0, ///
            msymbol(none) ///
            title("HbA1c", size(medsmall)) ///
            subtitle("No available data yet", size(small)) ///
            xtitle("Weeks from baseline", size(small)) ///
            ytitle("Mean change, mmol/mol", size(small)) ///
            xlabel(, labsize(small)) ///
            ylabel(-40(10)20, labsize(small)) ///
            yline(0) ///
            yscale(range(-40 20)) ///
            legend(off) ///
            xsize(6.2) ysize(3.8) ///
            name(group_hba1c_change, replace)
    }

    graph export "$figdir\group_hba1c_change_abs.png", replace width(1700)

restore


** -------------------------------------------------------------------------
** Count participants and group date range for group page
** -------------------------------------------------------------------------

quietly levelsof pid if include_outcome_monitoring == 1, local(pid_list_for_count)
local n_participants : word count `pid_list_for_count'

local group_baseline_date_txt ""
quietly summarize baseline_visit_date if include_outcome_monitoring == 1, meanonly
if r(N) > 0 {
    local group_baseline_date_txt : display %tdDD/NN/CCYY r(min)
}

local group_latest_visit_date_txt ""
quietly summarize visit_date_cm if include_outcome_monitoring == 1 & !missing(visit_date_cm), meanonly
if r(N) > 0 {
    local group_latest_visit_date_txt : display %tdDD/NN/CCYY r(max)
}


** -------------------------------------------------------------------------
** Create a compact text summary of withdrawal points
**
** The summary reports counts by planned visit, for example:
**
**     TMR visit 2 (1); Food visit 1 (1)
**
** If a completed withdrawal cannot be linked to a dated visit, this is
** shown as "Before baseline or visit unknown".
** -------------------------------------------------------------------------

local withdrawal_points_txt "None"

if `n_withdrawn' > 0 {

    local withdrawal_points_txt ""

    forvalues s = 1/15 {

        quietly count if ///
            participant_tag == 1 & ///
            started_programme == 1 & ///
            withdrawn == 1 & ///
            withdrawal_after_visit == `s'

        local n_withdrawn_after_visit = r(N)

        if `n_withdrawn_after_visit' > 0 {

            if "`withdrawal_points_txt'" == "" {
                local withdrawal_points_txt ///
                    "`rowlabel`s'' (`n_withdrawn_after_visit')"
            }
            else {
                local withdrawal_points_txt ///
                    "`withdrawal_points_txt'; `rowlabel`s'' (`n_withdrawn_after_visit')"
            }
        }
    }

    quietly count if ///
        participant_tag == 1 & ///
        started_programme == 1 & ///
        withdrawn == 1 & ///
        missing(withdrawal_after_visit)

    local n_withdrawal_visit_unknown = r(N)

    if `n_withdrawal_visit_unknown' > 0 {

        if "`withdrawal_points_txt'" == "" {
            local withdrawal_points_txt ///
                "Before baseline or visit unknown (`n_withdrawal_visit_unknown')"
        }
        else {
            local withdrawal_points_txt ///
                "`withdrawal_points_txt'; Before baseline or visit unknown (`n_withdrawal_visit_unknown')"
        }
    }
}



** -------------------------------------------------------------------------
** Begin PDF report
**
** Do not use putpdf paragraph, style(Title), style(Heading1),
** or putpdf table ..., names. These options are not accepted in this setup.
** -------------------------------------------------------------------------

putpdf clear
putpdf begin, pagesize(A4) ///
    margin(top, 0.5) margin(bottom, 0.5) ///
    margin(left, 0.5) margin(right, 0.5) ///
    font("Arial", 8)


** -------------------------------------------------------------------------
** Page 1: group summary
** -------------------------------------------------------------------------

putpdf paragraph
putpdf text ("TMR Diabetes Intervention: Outcome Monitoring"), bold font("Arial", 15)

** -------------------------------------------------------------------------
** Report metadata
**
** The original report information is retained. "Participants" is renamed
** "Started programme" so that its denominator is explicit.
** -------------------------------------------------------------------------

putpdf table group_header = (3,4), width(100%) border(all, nil)

putpdf table group_header(1,1) = ("Report")
putpdf table group_header(1,2) = ("Group summary")
putpdf table group_header(1,3) = ("Report date")
putpdf table group_header(1,4) = ("`report_date'")

putpdf table group_header(2,1) = ("Started programme")
putpdf table group_header(2,2) = ("`n_started'")
putpdf table group_header(2,3) = ("Earliest baseline")
putpdf table group_header(2,4) = ("`group_baseline_date_txt'")

putpdf table group_header(3,1) = ("")
putpdf table group_header(3,2) = ("")
putpdf table group_header(3,3) = ("Latest visit")
putpdf table group_header(3,4) = ("`group_latest_visit_date_txt'")

putpdf table group_header(.,.), font("Arial", 8)
putpdf table group_header(.,1), bold
putpdf table group_header(.,3), bold


** -------------------------------------------------------------------------
** Recruitment and screening metrics
**
** A two-row table is used to keep the six recruitment values compact.
** -------------------------------------------------------------------------

putpdf paragraph
putpdf text ("Recruitment and screening"), bold font("Arial", 9)

putpdf table recruitment_header = (3,6), ///
    width(100%) ///
    border(all, single)

putpdf table recruitment_header(1,1) = ("")
putpdf table recruitment_header(1,2) = ("Screened")
putpdf table recruitment_header(1,3) = ("Eligible")
putpdf table recruitment_header(1,4) = ("Interested")
putpdf table recruitment_header(1,5) = ("Not interested")
putpdf table recruitment_header(1,6) = ("Decision pending")

putpdf table recruitment_header(2,1) = ("Overall")
putpdf table recruitment_header(2,2) = ("`n_screened'")
putpdf table recruitment_header(2,3) = ("`eligible_display'")
putpdf table recruitment_header(2,4) = ("`interested_display'")
putpdf table recruitment_header(2,5) = ("`n_not_interested'")
putpdf table recruitment_header(2,6) = ("`n_decision_pending'")

putpdf table recruitment_header(3,1) = ("St Helena")
putpdf table recruitment_header(3,2) = ("`n_screened_sth'")
putpdf table recruitment_header(3,3) = ("`eligible_sth_display'")
putpdf table recruitment_header(3,4) = ("`interested_sth_display'")
putpdf table recruitment_header(3,5) = ("`n_not_interested_sth'")
putpdf table recruitment_header(3,6) = ("`n_decision_pending_sth'")

putpdf table recruitment_header(.,.), font("Arial", 7)
putpdf table recruitment_header(1,.), bold
putpdf table recruitment_header(2,1), bold
putpdf table recruitment_header(3,1), bold


** -------------------------------------------------------------------------
** Programme participation and retention metrics
** -------------------------------------------------------------------------

putpdf paragraph
putpdf text ("Programme participation and retention"), bold font("Arial", 9)

putpdf table programme_header = (2,5), ///
    width(100%) ///
    border(all, single)

putpdf table programme_header(1,1) = ("Started")
putpdf table programme_header(1,2) = ("Active")
putpdf table programme_header(1,3) = ("Withdrawn")
putpdf table programme_header(1,4) = ("Active: St Helena")
putpdf table programme_header(1,5) = ("Active: Ascension")

putpdf table programme_header(2,1) = ("`n_started'")
putpdf table programme_header(2,2) = ("`n_active'")
putpdf table programme_header(2,3) = ("`n_withdrawn'")
putpdf table programme_header(2,4) = ("`n_active_sth'")
putpdf table programme_header(2,5) = ("`n_active_asc'")

putpdf table programme_header(.,.), font("Arial", 7)
putpdf table programme_header(1,.), bold

putpdf paragraph
putpdf text ("Withdrawal points: "), bold font("Arial", 7)
putpdf text ("`withdrawal_points_txt'"), font("Arial", 7)

putpdf paragraph
putpdf text ("Group summary: mean values by planned visit"), bold font("Arial", 11)

putpdf paragraph
putpdf text ("The table below uses a standard visit structure. Empty cells indicate that no values are yet available for that outcome and visit."), font("Arial", 8)

** Adjust column widths so long visit labels have more room and the N column
** does not consume unnecessary space.
**
** putpdf requires relative column widths to be supplied as a matrix when the
** table is created. The eight percentages below sum to 100.
matrix group_visit_widths = ///
    (22, 5, 12.5, 12, 11, 13.5, 12, 12)

putpdf table group_visit_table = (16,8), ///
    width(group_visit_widths) ///
    border(all, single)

putpdf table group_visit_table(1,1) = ("Visit")
putpdf table group_visit_table(1,2) = ("N")
putpdf table group_visit_table(1,3) = ("Mean weight")
putpdf table group_visit_table(1,4) = ("Weight abs")
putpdf table group_visit_table(1,5) = ("Weight %")
putpdf table group_visit_table(1,6) = ("Mean HbA1c")
putpdf table group_visit_table(1,7) = ("HbA1c abs")
putpdf table group_visit_table(1,8) = ("HbA1c %")

putpdf table group_visit_table(.,.), font("Arial", 7)
putpdf table group_visit_table(1,.), bold

forvalues s = 1/15 {

    local row = `s' + 1

    local group_n ""
    quietly count if include_outcome_monitoring == 1 & visit_number == `s' & !missing(weight)
    if r(N) > 0 {
        local group_n : display %3.0f r(N)
    }

    local group_weight ""
    quietly summarize weight if include_outcome_monitoring == 1 & visit_number == `s', meanonly
    if r(N) > 0 {
        local group_weight : display %5.1f r(mean)
    }

    local group_weight_abs ""
    quietly summarize change_weight_abs if include_outcome_monitoring == 1 & visit_number == `s', meanonly
    if r(N) > 0 {
        local group_weight_abs : display %5.1f r(mean)
    }

    local group_weight_pct ""
    quietly summarize change_weight_pct if include_outcome_monitoring == 1 & visit_number == `s', meanonly
    if r(N) > 0 {
        local group_weight_pct : display %5.1f r(mean)
    }

    local group_hba1c ""
    quietly summarize hba1c if include_outcome_monitoring == 1 & visit_number == `s', meanonly
    if r(N) > 0 {
        local group_hba1c : display %5.1f r(mean)
    }

    local group_hba1c_abs ""
    quietly summarize change_hba1c_abs if include_outcome_monitoring == 1 & visit_number == `s', meanonly
    if r(N) > 0 {
        local group_hba1c_abs : display %5.1f r(mean)
    }

    local group_hba1c_pct ""
    quietly summarize change_hba1c_pct if include_outcome_monitoring == 1 & visit_number == `s', meanonly
    if r(N) > 0 {
        local group_hba1c_pct : display %5.1f r(mean)
    }

    putpdf table group_visit_table(`row',1) = ("`rowlabel`s''")
    putpdf table group_visit_table(`row',2) = ("`group_n'")
    putpdf table group_visit_table(`row',3) = ("`group_weight'")
    putpdf table group_visit_table(`row',4) = ("`group_weight_abs'")
    putpdf table group_visit_table(`row',5) = ("`group_weight_pct'")
    putpdf table group_visit_table(`row',6) = ("`group_hba1c'")
    putpdf table group_visit_table(`row',7) = ("`group_hba1c_abs'")
    putpdf table group_visit_table(`row',8) = ("`group_hba1c_pct'")
}

putpdf paragraph
putpdf text ("N is the number of non-missing weight values contributing to the visit mean. Change columns show absolute change and percentage change from baseline."), font("Arial", 7)

** -------------------------------------------------------------------------
** Group average change graphs
**
** Keep this section directly after the group summary table. With the revised
** table column widths, the graphs can use any remaining space on page 1.
** Individual participant pages retain their existing pagebreak.
** -------------------------------------------------------------------------

putpdf pagebreak

putpdf paragraph
putpdf text ("Group average absolute change over time"), bold font("Arial", 11)

putpdf table group_graphs = (1,2), width(100%) border(all, nil)

putpdf table group_graphs(1,1) = image("$figdir\group_weight_change_abs.png")
putpdf table group_graphs(1,2) = image("$figdir\group_hba1c_change_abs.png")


** -------------------------------------------------------------------------
** Individual participant pages
** -------------------------------------------------------------------------

sort pid visit_date_cm

** Individual outcome pages are created only for participants who have
** started the programme (recorded baseline visit). People who were screened
** but were ineligible, not interested, pending, or otherwise did not start
** remain represented in the recruitment summary but do not receive blank
** outcome pages.
levelsof pid if include_outcome_monitoring == 1, local(pid_list)

foreach p of local pid_list {

    preserve

        keep if pid == `p'
        sort visit_date_cm

        local participant_id = record_id_str[1]

        capture confirm string variable fname_padmin
        if !_rc {
            local fname = fname_padmin[1]
        }
        else {
            local fname ""
        }

        capture confirm string variable lname_padmin
        if !_rc {
            local lname = lname_padmin[1]
        }
        else {
            local lname ""
        }

        local person_name "`fname' `lname'"


        ** Participant dates and visit counts
        local baseline_date_txt ""
        quietly summarize baseline_visit_date, meanonly
        if r(N) > 0 {
            local baseline_date_txt : display %tdDD/NN/CCYY r(min)
        }

        local latest_visit_date_txt ""
        quietly summarize visit_date_cm if !missing(visit_date_cm), meanonly
        if r(N) > 0 {
            local latest_visit_date_txt : display %tdDD/NN/CCYY r(max)
        }

        quietly count if !missing(weight) | !missing(hba1c)
        local visits_completed = r(N)


        ** Individual graphs use all rows for this person

        ** Individual weight graph
        count if !missing(change_weight_abs) & !missing(weeks_from_baseline)

        if r(N) > 0 {
            twoway ///
                (connected change_weight_abs weeks_from_baseline if !missing(change_weight_abs), ///
                    msymbol(circle) msize(medium) lwidth(medthick)), ///
                title("Weight", size(medsmall)) ///
                xtitle("Weeks from baseline", size(small)) ///
                ytitle("Change, kg", size(small)) ///
                xlabel(, labsize(small)) ///
                ylabel(, labsize(small)) ///
                yline(0) ///
                legend(order(1 "Weight") pos(12) ring(0) cols(1) size(small)) ///
                xsize(6.2) ysize(3.8) ///
                name(person_`p'_weight_change, replace)
        }
        else {
            twoway scatteri 0 0, ///
                msymbol(none) ///
                title("Weight", size(medsmall)) ///
                subtitle("No available data", size(small)) ///
                xtitle("Weeks from baseline", size(small)) ///
                ytitle("Change, kg", size(small)) ///
                xlabel(, labsize(small)) ///
                ylabel(, labsize(small)) ///
                yline(0) ///
                legend(off) ///
                xsize(6.2) ysize(3.8) ///
                name(person_`p'_weight_change, replace)
        }

        graph export "$figdir\person_`p'_weight_change_abs.png", replace width(1700)


        ** Individual HbA1c graph
        count if !missing(change_hba1c_abs) & !missing(weeks_from_baseline)

        if r(N) > 0 {
            twoway ///
                (connected change_hba1c_abs weeks_from_baseline if !missing(change_hba1c_abs), ///
                    msymbol(circle) msize(medium) lwidth(medthick)), ///
                title("HbA1c", size(medsmall)) ///
                xtitle("Weeks from baseline", size(small)) ///
                ytitle("Change, mmol/mol", size(small)) ///
                xlabel(, labsize(small)) ///
                ylabel(-40(10)20, labsize(small)) ///
                yline(0) ///
                yscale(range(-40 20)) ///
                legend(order(1 "HbA1c") pos(12) ring(0) cols(1) size(small)) ///
                xsize(6.2) ysize(3.8) ///
                name(person_`p'_hba1c_change, replace)
        }
        else {
            twoway scatteri 0 0, ///
                msymbol(none) ///
                title("HbA1c", size(medsmall)) ///
                subtitle("No available data yet", size(small)) ///
                xtitle("Weeks from baseline", size(small)) ///
                ytitle("Change, mmol/mol", size(small)) ///
                xlabel(, labsize(small)) ///
                ylabel(-40(10)20, labsize(small)) ///
                yline(0) ///
                yscale(range(-40 20)) ///
                legend(off) ///
                xsize(6.2) ysize(3.8) ///
                name(person_`p'_hba1c_change, replace)
        }

        graph export "$figdir\person_`p'_hba1c_change_abs.png", replace width(1700)


        ** Start individual PDF page
        putpdf pagebreak

        putpdf paragraph
        putpdf text ("TMR Participant Outcome Monitoring"), bold font("Arial", 14)

        putpdf table person_header_`p' = (4,4), width(100%) border(all, nil)

        putpdf table person_header_`p'(1,1) = ("ID")
        putpdf table person_header_`p'(1,2) = ("`participant_id'")
        putpdf table person_header_`p'(1,3) = ("Report date")
        putpdf table person_header_`p'(1,4) = ("`report_date'")

        putpdf table person_header_`p'(2,1) = ("Name")
        putpdf table person_header_`p'(2,2) = (" ")
        putpdf table person_header_`p'(2,3) = ("Baseline date")
        putpdf table person_header_`p'(2,4) = ("`baseline_date_txt'")

        putpdf table person_header_`p'(3,1) = ("Visits completed")
        putpdf table person_header_`p'(3,2) = ("`visits_completed'")
        putpdf table person_header_`p'(3,3) = ("Final visit date")
        putpdf table person_header_`p'(3,4) = ("`latest_visit_date_txt'")

        putpdf table person_header_`p'(4,1) = ("")
        putpdf table person_header_`p'(4,2) = ("")
        putpdf table person_header_`p'(4,3) = ("")
        putpdf table person_header_`p'(4,4) = ("")

        putpdf table person_header_`p'(.,.), font("Arial", 8)
        putpdf table person_header_`p'(1,1), bold
        putpdf table person_header_`p'(2,1), bold
        putpdf table person_header_`p'(3,1), bold
        putpdf table person_header_`p'(1,3), bold
        putpdf table person_header_`p'(2,3), bold
        putpdf table person_header_`p'(3,3), bold

        putpdf paragraph
        putpdf text ("Visit values"), bold font("Arial", 10)

        putpdf table person_visit_table_`p' = (16,7), width(100%) border(all, single)

        putpdf table person_visit_table_`p'(1,1) = ("Visit")
        putpdf table person_visit_table_`p'(1,2) = ("Weight")
        putpdf table person_visit_table_`p'(1,3) = ("Weight abs")
        putpdf table person_visit_table_`p'(1,4) = ("Weight %")
        putpdf table person_visit_table_`p'(1,5) = ("HbA1c")
        putpdf table person_visit_table_`p'(1,6) = ("HbA1c abs")
        putpdf table person_visit_table_`p'(1,7) = ("HbA1c %")

        putpdf table person_visit_table_`p'(.,.), font("Arial", 7)
        putpdf table person_visit_table_`p'(1,.), bold

        forvalues s = 1/15 {

            local row = `s' + 1

            local person_weight ""
            quietly summarize weight if visit_number == `s', meanonly
            if r(N) > 0 {
                local person_weight : display %5.1f r(mean)
            }

            local person_weight_abs ""
            quietly summarize change_weight_abs if visit_number == `s', meanonly
            if r(N) > 0 {
                local person_weight_abs : display %5.1f r(mean)
            }

            local person_weight_pct ""
            quietly summarize change_weight_pct if visit_number == `s', meanonly
            if r(N) > 0 {
                local person_weight_pct : display %5.1f r(mean)
            }

            local person_hba1c ""
            quietly summarize hba1c if visit_number == `s', meanonly
            if r(N) > 0 {
                local person_hba1c : display %5.1f r(mean)
            }

            local person_hba1c_abs ""
            quietly summarize change_hba1c_abs if visit_number == `s', meanonly
            if r(N) > 0 {
                local person_hba1c_abs : display %5.1f r(mean)
            }

            local person_hba1c_pct ""
            quietly summarize change_hba1c_pct if visit_number == `s', meanonly
            if r(N) > 0 {
                local person_hba1c_pct : display %5.1f r(mean)
            }

            putpdf table person_visit_table_`p'(`row',1) = ("`rowlabel`s''")
            putpdf table person_visit_table_`p'(`row',2) = ("`person_weight'")
            putpdf table person_visit_table_`p'(`row',3) = ("`person_weight_abs'")
            putpdf table person_visit_table_`p'(`row',4) = ("`person_weight_pct'")
            putpdf table person_visit_table_`p'(`row',5) = ("`person_hba1c'")
            putpdf table person_visit_table_`p'(`row',6) = ("`person_hba1c_abs'")
            putpdf table person_visit_table_`p'(`row',7) = ("`person_hba1c_pct'")
        }

        putpdf paragraph
        putpdf text ("Change columns show absolute change and percentage change from baseline."), font("Arial", 7)

        putpdf paragraph
        putpdf text ("Absolute change from baseline over time"), bold font("Arial", 10)

        putpdf table person_graphs_`p' = (1,2), width(100%) border(all, nil)

        putpdf table person_graphs_`p'(1,1) = image("$figdir\person_`p'_weight_change_abs.png")
        putpdf table person_graphs_`p'(1,2) = image("$figdir\person_`p'_hba1c_change_abs.png")

    restore
}


** -------------------------------------------------------------------------
** Save PDF
** -------------------------------------------------------------------------

putpdf save "$pdfdir\tmr_monitor_report`report_date_file'_noname.pdf", replace

capture log close
