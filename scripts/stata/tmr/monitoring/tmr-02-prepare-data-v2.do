** HEADER -----------------------------------------------------
**  DO-FILE METADATA
    //  algorithm name             tmr-02-prepare-data-v2.do
    //  project:                   SH007 total meal replacement
    //  analysts:                  Ian HAMBLETON
    //  date last modified         01-Oct-2026
    //  workflow step              2 of 4
    //  algorithm task             Prepare the full TMR REDCap extract for
    //                              data-quality and monitoring reports

    ** General algorithm set-up
    version 19
    clear all
    macro drop _all
    args tmr_root tmr_map
    set more off
    set linesize 120

    ** Folder locations
    if `"`tmr_root'"' == "" local tmr_root "C:\yoshimi-hot\output\analyse-sth\sh007-total-meal-replacement\stata"
    global projectroot `"`tmr_root'"'
    global rawdir      "$projectroot\data_raw"
    global cleandir    "$projectroot\data_clean"
    global outputdir   "$projectroot\output"
    global figdir      "$projectroot\output\figures"
    global pdfdir      "$projectroot\output\pdf"
    global log         "$projectroot\logs"

    ** Create folders if they do not already exist
    capture mkdir "$rawdir"
    capture mkdir "$cleandir"
    capture mkdir "$outputdir"
    capture mkdir "$figdir"
    capture mkdir "$pdfdir"
    capture mkdir "$log"

    ** Close any open log file and open a new log file
    capture log close
    log using "$log\tmr-02-prepare-data-v2", replace
** HEADER -----------------------------------------------------


** =========================================================================
** PART 1. LOAD FULL RAW REDCAP API EXTRACT
** =========================================================================


** -------------------------------------------------------------------------
** Input dataset
**
** This file should be created by:
**
**     tmr-01-redcap-extract.do
**
** It is the full REDCap database export, saved as a stable "latest" file.
** The extraction do-file should also preserve dated raw archive copies.
** -------------------------------------------------------------------------

use "$rawdir\tmr_full_redcap_api_extract_latest.dta", clear

label data "TMR full REDCap extract: analysis-prepared dataset"

count
di as result "Rows loaded from full REDCap extract: " r(N)


** -------------------------------------------------------------------------
** Create date stamp for output files
** -------------------------------------------------------------------------

local today = c(current_date)
local today_file = subinstr("`today'", " ", "_", .)
local today_file = subinstr("`today_file'", "-", "_", .)

local clean_dta_dated  "$cleandir\tmr_full_analysis_dataset_`today_file'_v2.dta"
local clean_dta_latest "$cleandir\tmr_full_analysis_dataset_v2_latest.dta"


** =========================================================================
** PART 2. BASIC REDCAP METADATA HANDLING
** =========================================================================


** -------------------------------------------------------------------------
** REDCap metadata columns
**
** These four variables are not normal project fields:
**
**     redcap_event_name
**     redcap_repeat_instrument
**     redcap_repeat_instance
**     redcap_data_access_group
**
** They may or may not be present depending on the REDCap export structure.
** We create blank versions where needed so downstream code is stable.
** -------------------------------------------------------------------------

foreach v in redcap_event_name redcap_repeat_instrument redcap_repeat_instance redcap_data_access_group {
    capture confirm variable `v'
    if _rc {
        di as text "Metadata variable not present; creating blank variable: `v'"
        gen str1 `v' = ""
    }
}

capture label variable record_id "Participant Study ID"
capture label variable redcap_event_name "Event Name"
capture label variable redcap_repeat_instrument "Repeat Instrument"
capture label variable redcap_repeat_instance "Repeat Instance"
capture label variable redcap_data_access_group "Data Access Group"


** -------------------------------------------------------------------------
** Ensure record_id is string
**
** In REDCap, record_id is an identifier rather than an analysis measurement.
** Keeping it string avoids problems with leading zeroes or future ID formats.
** -------------------------------------------------------------------------

capture confirm variable record_id
if _rc {
    di as error "record_id not found. This is required."
    exit 111
}

capture confirm string variable record_id
if _rc {
    tostring record_id, replace usedisplayformat
}

replace record_id = strtrim(record_id)


** =========================================================================
** PART 3. DATE HANDLING
** =========================================================================


** -------------------------------------------------------------------------
** Known REDCap date variables
**
** These date variables were identified from the full REDCap export do-file.
** REDCap exports them as YMD strings. We convert them to Stata daily dates.
**
** This loop is defensive:
**     - If a date variable is string, convert from YMD string to Stata date.
**     - If a date variable is already numeric, simply apply the date format.
**     - If a date variable is absent, continue without stopping.
** -------------------------------------------------------------------------

local date_vars ///
    date_screen_1 ///
    dod_screen_1 ///
    dob_screen_1 ///
    date_dx_screen_1 ///
    date_hba1c_screen_1 ///
    date_rx_screen_1 ///
    date_ref_screen_1 ///
    date_dx_screen_2 ///
    date_screen_2 ///
    dob_screen_2 ///
    dob_padmin ///
    date_dx_padmin ///
    consent_date ///
    visit_date_cm ///
    visit_date_anth ///
    visit_date_hba1c ///
    visit_date_lm ///
    results_date ///
    visit_date_em ///
    fibroscan_date ///
    visit_date_he ///
    date_withdrawal ///
    dlc_withdrawal ///
    date_ae

foreach d of local date_vars {

    capture confirm variable `d'

    if !_rc {

        capture confirm string variable `d'

        if !_rc {
            gen _date_ = date(`d', "YMD")
            drop `d'
            rename _date_ `d'
            format `d' %dM_d,_CY
        }
        else {
            format `d' %dM_d,_CY
        }
    }
    else {
        di as text "Date variable not present and therefore not converted: `d'"
    }
}


** =========================================================================
** PART 4. NUMERIC CONVERSION
** =========================================================================


** -------------------------------------------------------------------------
** Convert string variables that are really numeric
**
** The raw API extraction imports variables cautiously. Some numeric variables
** may therefore arrive as strings. This loop attempts to destring all string
** variables. Variables containing true text, such as names, notes, email
** addresses, and uploaded file references, will be left unchanged.
**
** This is computationally simple and robust for REDCap flat exports.
** -------------------------------------------------------------------------

ds, has(type string)
local string_vars `r(varlist)'

foreach v of local string_vars {
    capture destring `v', replace ignore(" ")
}


** -------------------------------------------------------------------------
** Re-confirm record_id and REDCap text metadata as strings
**
** The destring loop should not convert these where they contain text, but we
** keep this defensive block in case a small early test dataset contains only
** numeric-looking identifiers.
** -------------------------------------------------------------------------

foreach v in record_id redcap_event_name redcap_repeat_instrument redcap_data_access_group {
    capture confirm variable `v'
    if !_rc {
        capture confirm string variable `v'
        if _rc {
            tostring `v', replace usedisplayformat
        }
    }
}


** =========================================================================
** PART 5. VALUE LABELS
** =========================================================================


** -------------------------------------------------------------------------
** Value labels
**
** These match the REDCap coding scheme from the full export do-file.
** Existing value label definitions are replaced so the do-file can be run
** repeatedly without stopping.
** -------------------------------------------------------------------------

label define sex_screen_1_ 1 "Female" 2 "Male", replace
label define vstatus_screen_1_ 1 "Alive" 2 "Dead", replace
label define diab_type_screen_1_ 1 "Type 1" 2 "Type 2" 3 "Gestational", replace
label define interested_screen_1_ 1 "Interested" 2 "Possibly interested" 3 "Not interested", replace
label define eligibility_screenin_v_0_ 0 "Incomplete" 1 "Unverified" 2 "Complete", replace

label define sex_screen_2_ 1 "Female" 2 "Male", replace
label define dobsame_screen_2_ 1 "Yes, same" 2 "No", replace
label define exclusion_screen_2_ 1 "Yes" 2 "No, none", replace
label define diagnosis_ed_screen_2_ 1 "Yes" 2 "No", replace
label define type_ed_screen_2_ 1 "Anorexia Nervosa" 2 "Bulimia Nervosa" 3 "Other", replace
label define des_q1_screen_2_ 1 "Yes" 2 "No" 3 "Unsure", replace
label define des_q1a_screen_2_ 1 "Yes" 2 "No", replace
label define des_q1b_screen_2_ 1 "Yes" 2 "No", replace
label define des_q1c_screen_2_ 1 "Yes" 2 "No", replace
label define des_q2_screen_2_ 0 "Less than once a month" 1 "About once a month" 2 "A few times a month" 3 "About once a week" 4 "About three times a week" 5 "Daily", replace
label define des_q3_screen_2_ 3 "Yes" 1 "No", replace
label define des_q4_screen_2_ 0 "Less than once a month" 1 "About once a month" 2 "A few times a month" 3 "About once a week" 4 "About three times a week", replace
label define interested_screen_2_ 1 "Yes" 2 "No" 3 "Maybe", replace
label define eligibility_screenin_v_1_ 0 "Incomplete" 1 "Unverified" 2 "Complete", replace

label define sex_padmin_ 1 "Female" 2 "Male", replace
label define site_ 1 "St Helena" 2 "Ascension", replace
label define preferred_location_ 1 "Jamestown" 2 "Levelwood" 3 "Longwood" 4 "Half Tree Hollow", replace
label define consent_obtained_ 1 "Yes" 2 "No", replace
label define participant_admin_complete_ 0 "Incomplete" 1 "Unverified" 2 "Complete", replace

label define diabetes_meds_ 5 "not taking medication(s)" 1 "monotherapy oral" 2 "monotherapy injectable" 3 "combination of 2 drugs" 4 "combination of 3 or more drugs" 6 "stopped medication(s)", replace
label define hypertension_meds_ 1 "Yes" 2 "No, not taking medication(s)" 3 "Stopped medication(s)", replace
label define smoking_ 1 "Yes" 2 "No", replace
label define smoking_past_ 1 "Yes" 2 "No", replace
label define core_measurements_complete_ 0 "Incomplete" 1 "Unverified" 2 "Complete", replace
label define anthropometry_complete_ 0 "Incomplete" 1 "Unverified" 2 "Complete", replace
label define hba1c_complete_ 0 "Incomplete" 1 "Unverified" 2 "Complete", replace
label define lab_measurements_complete_ 0 "Incomplete" 1 "Unverified" 2 "Complete", replace
label define expanded_measurements_complete_ 0 "Incomplete" 1 "Unverified" 2 "Complete", replace
label define health_economics_complete_ 0 "Incomplete" 1 "Unverified" 2 "Complete", replace

label define eq_mob_ 1 "No problems" 2 "Some problems" 3 "Extreme problems", replace
label define eq_sc_ 1 "No problems" 2 "Some problems" 3 "Extreme problems", replace
label define eq_ua_ 1 "No problems" 2 "Some problems" 3 "Extreme problems", replace
label define eq_pd_ 1 "No problems" 2 "Some problems" 3 "Extreme problems", replace
label define eq_ad_ 1 "No problems" 2 "Some problems" 3 "Extreme problems", replace

label define paid_problem_ 0 "Not a problem" 1 "Minor problem" 2 "Moderate problem" 3 "Somewhat serious problem" 4 "Serious problem", replace

label define he_currency_ 1 "GBP" 2 "ZAR" 3 "Other", replace

label define phase_withdrawal_ 1 "TDR" 2 "food reintroduction" 3 "maintenance", replace
label define type_withdrawal_ 1 "Yes" 2 "No" 3 "Maybe", replace
label define reason_withdrawal_ 1 "Medical / adverse effects" 2 "Programme burden (time, logistics, products)" 3 "Psychological or social reasons" 4 "Loss of motivation / preference change" 5 "Competing illness or life event" 6 "Moved away / unavailable" 7 "Participant died" 8 "Other (specify)", replace
label define ae_withdrawal_rpt_ 1 "Yes" 2 "No", replace
label define initiated_withdrawal_ 1 "participant" 2 "service", replace
label define withdrawal_form_complete_ 0 "Incomplete" 1 "Unverified" 2 "Complete", replace
label define class_ae_ 1 "adverse event" 2 "serious adverse event", replace
label define adverse_event_complete_ 0 "Incomplete" 1 "Unverified" 2 "Complete", replace


** -------------------------------------------------------------------------
** Attach value labels only where variables exist
** -------------------------------------------------------------------------

capture label values sex_screen_1 sex_screen_1_
capture label values vstatus_screen_1 vstatus_screen_1_
capture label values diab_type_screen_1 diab_type_screen_1_
capture label values interested_screen_1 interested_screen_1_
capture label values eligibility_screenin_v_0 eligibility_screenin_v_0_

capture label values sex_screen_2 sex_screen_2_
capture label values dobsame_screen_2 dobsame_screen_2_
capture label values exclusion_screen_2 exclusion_screen_2_
capture label values diagnosis_ed_screen_2 diagnosis_ed_screen_2_
capture label values type_ed_screen_2 type_ed_screen_2_
capture label values des_q1_screen_2 des_q1_screen_2_
capture label values des_q1a_screen_2 des_q1a_screen_2_
capture label values des_q1b_screen_2 des_q1b_screen_2_
capture label values des_q1c_screen_2 des_q1c_screen_2_
capture label values des_q2_screen_2 des_q2_screen_2_
capture label values des_q3_screen_2 des_q3_screen_2_
capture label values des_q4_screen_2 des_q4_screen_2_
capture label values interested_screen_2 interested_screen_2_
capture label values eligibility_screenin_v_1 eligibility_screenin_v_1_

capture label values sex_padmin sex_padmin_
capture label values site site_
capture label values preferred_location preferred_location_
capture label values consent_obtained consent_obtained_
capture label values participant_admin_complete participant_admin_complete_

capture label values diabetes_meds diabetes_meds_
capture label values hypertension_meds hypertension_meds_
capture label values smoking smoking_
capture label values smoking_past smoking_past_
capture label values core_measurements_complete core_measurements_complete_
capture label values anthropometry_complete anthropometry_complete_
capture label values hba1c_complete hba1c_complete_
capture label values lab_measurements_complete lab_measurements_complete_
capture label values expanded_measurements_complete expanded_measurements_complete_
capture label values health_economics_complete health_economics_complete_

capture label values eq_mob eq_mob_
capture label values eq_sc eq_sc_
capture label values eq_ua eq_ua_
capture label values eq_pd eq_pd_
capture label values eq_ad eq_ad_

foreach v in paid01 paid02 paid03 paid04 paid05 paid06 paid07 paid08 paid09 paid10 ///
             paid11 paid12 paid13 paid14 paid15 paid16 paid17 paid18 paid19 paid20 {
    capture label values `v' paid_problem_
}

capture label values he_currency he_currency_

capture label values phase_withdrawal phase_withdrawal_
capture label values type_withdrawal type_withdrawal_
capture label values reason_withdrawal reason_withdrawal_
capture label values ae_withdrawal_rpt ae_withdrawal_rpt_
capture label values initiated_withdrawal initiated_withdrawal_
capture label values withdrawal_form_complete withdrawal_form_complete_
capture label values class_ae class_ae_
capture label values adverse_event_complete adverse_event_complete_


** =========================================================================
** PART 6. VARIABLE LABELS
** =========================================================================


** -------------------------------------------------------------------------
** Key identifiers and metadata
** -------------------------------------------------------------------------

capture label variable record_id "Participant Study ID"
capture label variable redcap_event_name "REDCap event name"
capture label variable redcap_repeat_instrument "REDCap repeating instrument"
capture label variable redcap_repeat_instance "REDCap repeat instance"
capture label variable redcap_data_access_group "REDCap data access group"


** -------------------------------------------------------------------------
** Screening arm: initial screening variables
** -------------------------------------------------------------------------

capture label variable date_screen_1 "Screening arm: date of initial screening"
capture label variable emis_id_screen_1 "Screening arm: EMIS ID"
capture label variable fname_screen_1 "Screening arm: first name"
capture label variable lname_screen_1 "Screening arm: last name"
capture label variable sex_screen_1 "Screening arm: participant sex"
capture label variable phone_screen_1 "Screening arm: phone number 1"
capture label variable phone2_screen_1 "Screening arm: phone number 2"
capture label variable phone3_screen_1 "Screening arm: phone number 3"
capture label variable email_screen_1 "Screening arm: email address 1"
capture label variable email2_screen_1 "Screening arm: email address 2"
capture label variable vstatus_screen_1 "Screening arm: vital status"
capture label variable dod_screen_1 "Screening arm: date of death"
capture label variable diab_type_screen_1 "Screening arm: diabetes type"
capture label variable dob_screen_1 "Screening arm: date of birth"
capture label variable date_dx_screen_1 "Screening arm: date of diabetes diagnosis"
capture label variable date_hba1c_screen_1 "Screening arm: date of last known HbA1c test"
capture label variable hba1c_screen_1 "Screening arm: last known HbA1c result"
capture label variable date_rx_screen_1 "Screening arm: date of last known diabetes prescription"
capture label variable date_ref_screen_1 "Screening arm: study reference date"
capture label variable age_screen_1 "Screening arm: age"
capture label variable ddur_screen_1 "Screening arm: diabetes duration in years"
capture label variable ddur_screen_1_asi "Screening arm: diabetes duration in years, Ascension"
capture label variable interested_screen_1 "Screening arm: interest in TMR pilot"
capture label variable eligibility_screenin_v_0 "Screening arm: initial screening completion status"


** -------------------------------------------------------------------------
** Screening arm: eligibility / extended screening variables
** -------------------------------------------------------------------------

capture label variable emis_id_screen_2 "Eligibility screening: EMIS ID"
capture label variable fname_screen_2 "Eligibility screening: first name"
capture label variable lname_screen_2 "Eligibility screening: last name"
capture label variable sex_screen_2 "Eligibility screening: participant sex"
capture label variable phone_screen_2 "Eligibility screening: phone number 1"
capture label variable phone2_screen_2 "Eligibility screening: phone number 2"
capture label variable phone3_screen_2 "Eligibility screening: phone number 3"
capture label variable email_screen_2 "Eligibility screening: email address 1"
capture label variable email2_screen_2 "Eligibility screening: email address 2"
capture label variable date_dx_screen_2 "Eligibility screening: date of diabetes diagnosis"
capture label variable date_screen_2 "Eligibility screening: date of screening"
capture label variable dobsame_screen_2 "Eligibility screening: date of birth confirmed"
capture label variable dob_screen_2 "Eligibility screening: date of birth"
capture label variable age_screen_2 "Eligibility screening: age"
capture label variable exclusion_screen_2 "Eligibility screening: exclusion criteria present"
capture label variable height_screen_2 "Eligibility screening: height in cm"
capture label variable weight_screen_2 "Eligibility screening: weight in kg"
capture label variable bmi_screen_2 "Eligibility screening: BMI"
capture label variable diagnosis_ed_screen_2 "Eligibility screening: previous eating disorder diagnosis"
capture label variable type_ed_screen_2 "Eligibility screening: eating disorder type"
capture label variable type_ed_oth_screen_2 "Eligibility screening: other eating disorder type"
capture label variable des_score_screen_2 "Eligibility screening: diabetes eating problem survey score"
capture label variable group_screen_2 "Eligibility screening: group"
capture label variable interested_screen_2 "Eligibility screening: interest in TMR pilot"
capture label variable eligibility_screenin_v_1 "Eligibility screening: completion status"


** -------------------------------------------------------------------------
** Programme arm: participant administration
** -------------------------------------------------------------------------

capture label variable emis_id_padmin "Programme arm: EMIS ID"
capture label variable fname_padmin "Programme arm: first name"
capture label variable lname_padmin "Programme arm: last name"
capture label variable sex_padmin "Programme arm: participant sex"
capture label variable dob_padmin "Programme arm: date of birth"
capture label variable phone_padmin "Programme arm: phone number 1"
capture label variable phone2_padmin "Programme arm: phone number 2"
capture label variable phone3_padmin "Programme arm: phone number 3"
capture label variable email_padmin "Programme arm: email address 1"
capture label variable email2_padmin "Programme arm: email address 2"
capture label variable date_dx_padmin "Programme arm: date of diabetes diagnosis"
capture label variable height_padmin "Programme arm: height in cm"
capture label variable site "Programme arm: study site"
capture label variable preferred_location "Programme arm: preferred clinic location"
capture label variable consent_obtained "Programme arm: informed consent obtained"
capture label variable consent_date "Programme arm: informed consent date"
capture label variable consent_form "Programme arm: signed consent form upload"
capture label variable participant_admin_complete "Programme arm: participant administration completion status"


** -------------------------------------------------------------------------
** Programme arm: measurement variables
** -------------------------------------------------------------------------

capture label variable visit_date_cm "Programme arm: core measurements visit date"
capture label variable weight "Programme arm: weight in kg"
capture label variable waist "Programme arm: waist circumference in cm"
capture label variable hip "Programme arm: hip circumference in cm"
capture label variable sbp1 "Programme arm: systolic blood pressure reading 1"
capture label variable dbp1 "Programme arm: diastolic blood pressure reading 1"
capture label variable sbp2 "Programme arm: systolic blood pressure reading 2"
capture label variable dbp2 "Programme arm: diastolic blood pressure reading 2"
capture label variable sbp3 "Programme arm: systolic blood pressure reading 3"
capture label variable dbp3 "Programme arm: diastolic blood pressure reading 3"
capture label variable glucose "Programme arm: blood glucose in mmol/L"
capture label variable diabetes_meds "Programme arm: diabetes medication status"
capture label variable hypertension_meds "Programme arm: hypertension medication status"
capture label variable smoking "Programme arm: current smoking"
capture label variable smoking_past "Programme arm: past smoking"
capture label variable core_measurements_complete "Programme arm: core measurements completion status"

capture label variable visit_date_anth "Programme arm: anthropometry visit date"
capture label variable anthropometry_complete "Programme arm: anthropometry completion status"

capture label variable visit_date_hba1c "Programme arm: HbA1c visit date"
capture label variable hba1c "Programme arm: HbA1c in mmol/mol"
capture label variable hba1c_complete "Programme arm: HbA1c completion status"

capture label variable visit_date_lm "Programme arm: lab measurements visit date"
capture label variable results_date "Programme arm: lab results date"
capture label variable hba1c_copy "Programme arm: HbA1c copied into lab measurements"
capture label variable alt "Programme arm: ALT in U/L"
capture label variable ast "Programme arm: AST in U/L"
capture label variable alp "Programme arm: ALP in U/L"
capture label variable bilirubin_total "Programme arm: total bilirubin in µmol/L"
capture label variable albumin "Programme arm: albumin in g/L"
capture label variable protein_total "Programme arm: total protein in g/L"
capture label variable ggt "Programme arm: GGT in U/L"
capture label variable hb "Programme arm: haemoglobin in g/dL"
capture label variable cholesterol_total "Programme arm: total cholesterol in mmol/L"
capture label variable cholesterol_hdl "Programme arm: HDL cholesterol in mmol/L"
capture label variable cholesterol_ldl "Programme arm: LDL cholesterol in mmol/L"
capture label variable triglyceride "Programme arm: triglycerides in mmol/L"
capture label variable sodium "Programme arm: sodium in mmol/L"
capture label variable potassium "Programme arm: potassium in mmol/L"
capture label variable urea "Programme arm: urea in mmol/L"
capture label variable creatinine "Programme arm: creatinine in µmol/L"
capture label variable egfr "Programme arm: eGFR in mL/min/1.73m2"
capture label variable lab_measurements_complete "Programme arm: lab measurements completion status"

capture label variable visit_date_em "Programme arm: expanded measurements visit date"
capture label variable fibroscan_date "Programme arm: FibroScan assessment date"
capture label variable lsm_kpa "Programme arm: liver stiffness measurement in kPa"
capture label variable lsm_iqr "Programme arm: liver stiffness IQR in kPa"
capture label variable cap_dbm "Programme arm: controlled attenuation parameter in dB/m"
capture label variable cap_sd "Programme arm: CAP standard deviation in dB/m"
capture label variable eq_mob "Programme arm: EQ-5D mobility"
capture label variable eq_sc "Programme arm: EQ-5D self-care"
capture label variable eq_ua "Programme arm: EQ-5D usual activities"
capture label variable eq_pd "Programme arm: EQ-5D pain or discomfort"
capture label variable eq_ad "Programme arm: EQ-5D anxiety or depression"
capture label variable eq_vas "Programme arm: EQ VAS health score"
capture label variable expanded_measurements_complete "Programme arm: expanded measurements completion status"

capture label variable visit_date_he "Programme arm: health economics visit date"
capture label variable he_currency "Programme arm: currency used for costing"
capture label variable he_currency_oth "Programme arm: other costing currency"
capture label variable he_insulin_supplied "Programme arm: weeks of insulin supplied"
capture label variable he_metformin_supplied "Programme arm: weeks of metformin supplied"
capture label variable he_antihyp_supplied "Programme arm: weeks of antihypertensive supplied"
capture label variable he_notes "Programme arm: health economics notes"
capture label variable health_economics_complete "Programme arm: health economics completion status"


** -------------------------------------------------------------------------
** Withdrawal and adverse event variables
** -------------------------------------------------------------------------

capture label variable study_id_withdrawal "Withdrawal form: participant study ID"
capture label variable date_withdrawal "Withdrawal form: date of withdrawal"
capture label variable phase_withdrawal "Withdrawal form: programme phase at withdrawal"
capture label variable type_withdrawal "Withdrawal form: continued monitoring requested"
capture label variable reason_withdrawal "Withdrawal form: primary reason for withdrawal"
capture label variable reason_withdrawal_oth "Withdrawal form: other withdrawal reason"
capture label variable ae_withdrawal_rpt "Withdrawal form: adverse event already reported"
capture label variable dlc_withdrawal "Withdrawal form: date of last contact"
capture label variable initiated_withdrawal "Withdrawal form: withdrawal initiated by"
capture label variable withdrawal_form_complete "Withdrawal form: completion status"

capture label variable study_id_ae "Adverse event form: participant study ID"
capture label variable date_ae "Adverse event form: date of adverse event"
capture label variable notes_ae "Adverse event form: notes"
capture label variable class_ae "Adverse event form: classification"
capture label variable adverse_event_complete "Adverse event form: completion status"


** =========================================================================
** PART 7. SCREENING ARM DERIVED VARIABLES
** =========================================================================


** -------------------------------------------------------------------------
** Screening-arm flags
**
** Short variable names are used to avoid Stata's 32-character name limit.
**
**     has_scr1 = row has initial screening data
**     has_scr2 = row has eligibility screening data
**     has_scr  = row has any screening data
** -------------------------------------------------------------------------

gen byte has_scr1 = 0
gen byte has_scr2 = 0

local screening_1_vars ///
    date_screen_1 emis_id_screen_1 fname_screen_1 lname_screen_1 sex_screen_1 ///
    phone_screen_1 phone2_screen_1 phone3_screen_1 email_screen_1 email2_screen_1 ///
    vstatus_screen_1 dod_screen_1 diab_type_screen_1 dob_screen_1 date_dx_screen_1 ///
    date_hba1c_screen_1 hba1c_screen_1 date_rx_screen_1 date_ref_screen_1 ///
    age_screen_1 ddur_screen_1 ddur_screen_1_asi interested_screen_1 ///
    eligibility_screenin_v_0

foreach v of local screening_1_vars {
    capture confirm variable `v'
    if !_rc {
        replace has_scr1 = 1 if !missing(`v')
    }
}

local screening_2_vars ///
    emis_id_screen_2 fname_screen_2 lname_screen_2 sex_screen_2 ///
    phone_screen_2 phone2_screen_2 phone3_screen_2 email_screen_2 email2_screen_2 ///
    date_dx_screen_2 date_screen_2 dobsame_screen_2 dob_screen_2 age_screen_2 ///
    exclusion_screen_2 height_screen_2 weight_screen_2 bmi_screen_2 ///
    diagnosis_ed_screen_2 type_ed_screen_2 type_ed_oth_screen_2 ///
    des_q1_screen_2 des_q1a_screen_2 des_q1b_screen_2 des_q1c_screen_2 ///
    score_q1_no_screen_2 score_q1_yes_screen_2 des_q2_screen_2 des_q3_screen_2 ///
    des_q4_screen_2 des_score_screen_2 group_screen_2 interested_screen_2 ///
    eligibility_screenin_v_1

foreach v of local screening_2_vars {
    capture confirm variable `v'
    if !_rc {
        replace has_scr2 = 1 if !missing(`v')
    }
}

gen byte has_scr = has_scr1 == 1 | has_scr2 == 1

label variable has_scr1 "Analysis flag: row has initial screening data"
label variable has_scr2 "Analysis flag: row has eligibility screening data"
label variable has_scr "Analysis flag: row has any screening data"

label define yesno_flag 0 "No" 1 "Yes", replace
label values has_scr1 yesno_flag
label values has_scr2 yesno_flag
label values has_scr yesno_flag


** -------------------------------------------------------------------------
** Screening stage
**
**     0 = no screening data on this row
**     1 = initial screening only
**     2 = eligibility screening only
**     3 = both screening stages represented on this row
** -------------------------------------------------------------------------

gen byte scr_stage = .
replace scr_stage = 0 if has_scr == 0
replace scr_stage = 1 if has_scr1 == 1 & has_scr2 == 0
replace scr_stage = 2 if has_scr1 == 0 & has_scr2 == 1
replace scr_stage = 3 if has_scr1 == 1 & has_scr2 == 1

label define scr_stage_lbl ///
    0 "No screening data" ///
    1 "Initial screening" ///
    2 "Eligibility screening" ///
    3 "Initial and eligibility screening", replace

label values scr_stage scr_stage_lbl
label variable scr_stage "Analysis: screening stage represented on row"


** -------------------------------------------------------------------------
** Screening-level participant indicators
** -------------------------------------------------------------------------

bysort record_id: egen p_has_scr1 = max(has_scr1)
bysort record_id: egen p_has_scr2 = max(has_scr2)
bysort record_id: egen p_has_scr = max(has_scr)

label variable p_has_scr1 "Participant has any initial screening data"
label variable p_has_scr2 "Participant has any eligibility screening data"
label variable p_has_scr "Participant has any screening data"

label values p_has_scr1 yesno_flag
label values p_has_scr2 yesno_flag
label values p_has_scr yesno_flag


** =========================================================================
** PART 8. PROGRAMME ARM DERIVED VARIABLES
** =========================================================================


** -------------------------------------------------------------------------
** Programme-arm flags
**
** Short variable names are used to avoid Stata's 32-character name limit.
**
**     has_padmin = row has programme administration data
**     has_pmeas  = row has programme measurement data
**     has_pwd    = row has withdrawal data
**     has_pae    = row has adverse event data
**     has_prog   = row has any programme-arm data
** -------------------------------------------------------------------------

gen byte has_padmin = 0
gen byte has_pmeas = 0
gen byte has_pwd = 0
gen byte has_pae = 0

local programme_admin_vars ///
    emis_id_padmin fname_padmin lname_padmin sex_padmin dob_padmin ///
    phone_padmin phone2_padmin phone3_padmin email_padmin email2_padmin ///
    date_dx_padmin height_padmin site preferred_location consent_obtained ///
    consent_date consent_form participant_admin_complete

foreach v of local programme_admin_vars {
    capture confirm variable `v'
    if !_rc {
        replace has_padmin = 1 if !missing(`v')
    }
}

local programme_measurement_vars ///
    visit_date_cm weight waist hip sbp1 dbp1 sbp2 dbp2 sbp3 dbp3 glucose ///
    diabetes_meds hypertension_meds smoking smoking_past core_measurements_complete ///
    visit_date_anth anthropometry_complete ///
    visit_date_hba1c hba1c hba1c_complete ///
    visit_date_lm results_date hba1c_copy alt ast alp bilirubin_total albumin ///
    protein_total ggt hb cholesterol_total cholesterol_hdl cholesterol_ldl ///
    triglyceride sodium potassium urea creatinine egfr lab_measurements_complete ///
    visit_date_em fibroscan_date lsm_kpa lsm_iqr cap_dbm cap_sd ///
    eq_mob eq_sc eq_ua eq_pd eq_ad eq_vas ///
    paid01 paid02 paid03 paid04 paid05 paid06 paid07 paid08 paid09 paid10 ///
    paid11 paid12 paid13 paid14 paid15 paid16 paid17 paid18 paid19 paid20 ///
    ipaq_walk_days ipaq_walk_mins ipaq_mod_days ipaq_mod_mins ///
    ipaq_vig_days ipaq_vig_mins ipaq_sit_mins expanded_measurements_complete ///
    visit_date_he he_currency he_currency_oth he_insulin_supplied ///
    he_metformin_supplied he_antihyp_supplied he_notes health_economics_complete

foreach v of local programme_measurement_vars {
    capture confirm variable `v'
    if !_rc {
        replace has_pmeas = 1 if !missing(`v')
    }
}

local programme_withdrawal_vars ///
    study_id_withdrawal date_withdrawal phase_withdrawal type_withdrawal ///
    reason_withdrawal reason_withdrawal_oth ae_withdrawal_rpt dlc_withdrawal ///
    initiated_withdrawal withdrawal_form_complete

foreach v of local programme_withdrawal_vars {
    capture confirm variable `v'
    if !_rc {
        replace has_pwd = 1 if !missing(`v')
    }
}

local programme_ae_vars ///
    study_id_ae date_ae notes_ae class_ae adverse_event_complete

foreach v of local programme_ae_vars {
    capture confirm variable `v'
    if !_rc {
        replace has_pae = 1 if !missing(`v')
    }
}

gen byte has_prog = ///
    has_padmin == 1 | ///
    has_pmeas == 1 | ///
    has_pwd == 1 | ///
    has_pae == 1

label variable has_padmin "Analysis flag: row has programme administration data"
label variable has_pmeas "Analysis flag: row has programme measurement data"
label variable has_pwd "Analysis flag: row has withdrawal data"
label variable has_pae "Analysis flag: row has adverse event data"
label variable has_prog "Analysis flag: row has any programme data"

label values has_padmin yesno_flag
label values has_pmeas yesno_flag
label values has_pwd yesno_flag
label values has_pae yesno_flag
label values has_prog yesno_flag


** -------------------------------------------------------------------------
** Participant-level programme indicators
** -------------------------------------------------------------------------

bysort record_id: egen p_has_padmin = max(has_padmin)
bysort record_id: egen p_has_pmeas = max(has_pmeas)
bysort record_id: egen p_has_pwd = max(has_pwd)
bysort record_id: egen p_has_pae = max(has_pae)
bysort record_id: egen p_has_prog = max(has_prog)

label variable p_has_padmin "Participant has programme administration data"
label variable p_has_pmeas "Participant has programme measurement data"
label variable p_has_pwd "Participant has withdrawal data"
label variable p_has_pae "Participant has adverse event data"
label variable p_has_prog "Participant has any programme data"

label values p_has_padmin yesno_flag
label values p_has_pmeas yesno_flag
label values p_has_pwd yesno_flag
label values p_has_pae yesno_flag
label values p_has_prog yesno_flag


** -------------------------------------------------------------------------
** Overall analysis arm
**
**     1 = screening arm only
**     2 = programme arm only
**     3 = screening and programme data on same row
**     4 = neither screening nor programme data identified
** -------------------------------------------------------------------------

gen byte analysis_arm = .
replace analysis_arm = 1 if has_scr == 1 & has_prog == 0
replace analysis_arm = 2 if has_scr == 0 & has_prog == 1
replace analysis_arm = 3 if has_scr == 1 & has_prog == 1
replace analysis_arm = 4 if has_scr == 0 & has_prog == 0

label define analysis_arm_lbl ///
    1 "Screening arm only" ///
    2 "Programme arm only" ///
    3 "Screening and programme arm" ///
    4 "Neither arm identified", replace

label values analysis_arm analysis_arm_lbl
label variable analysis_arm "Analysis: broad arm represented on row"


** =========================================================================
** PART 9. PROGRAMME VISIT CLASSIFICATION
** =========================================================================


** -------------------------------------------------------------------------
** Programme visit date
**
** Multiple programme instruments may have different visit-date variables.
** We create one operational programme visit date using the first non-missing
** date in this priority order:
**
**     1. Core measurements date
**     2. Anthropometry date
**     3. HbA1c date
**     4. Laboratory measurements visit date
**     5. Expanded measurements visit date
**     6. Health economics visit date
**
** This is deliberately simple. It gives each row a single analysis visit date.
** -------------------------------------------------------------------------

gen prog_visit_date = .

foreach d in visit_date_cm visit_date_anth visit_date_hba1c visit_date_lm visit_date_em visit_date_he {
    capture confirm variable `d'
    if !_rc {
        replace prog_visit_date = `d' if missing(prog_visit_date) & !missing(`d')
    }
}

format prog_visit_date %dM_d,_CY
label variable prog_visit_date "Analysis: programme visit date"


** -------------------------------------------------------------------------
** Visit identity v2: exact REDCap event/instance lookup, never date counting.
** Map columns: redcap_event_name, repeat_instance, planned_visit,
**              display_order, visit_label.
** planned_visit: 1-20 = scheduled; 0 = optional; . = not a measurement visit.
** repeat_instance: 0 = non-repeating; otherwise the exported instance number.
** Map every measurement event/instance. The map audit utility creates a draft.

sort record_id prog_visit_date redcap_repeat_instance redcap_event_name
by record_id prog_visit_date: gen byte _first_prog_date = (_n == 1) if !missing(prog_visit_date)
by record_id: gen prog_visit_seq = sum(_first_prog_date) if !missing(prog_visit_date)
drop _first_prog_date
label variable prog_visit_seq "Chronological sequence of recorded dates (not planned visit)"

capture confirm numeric variable redcap_repeat_instance
if _rc {
    destring redcap_repeat_instance, replace
}
gen long repeat_instance = redcap_repeat_instance
replace repeat_instance = 0 if missing(repeat_instance)

if `"`tmr_map'"' == "" local tmr_map "$projectroot/config/tmr-visit-map.csv"
capture confirm file `"`tmr_map'"'
if _rc {
    di as error "Visit map not found: `tmr_map'"
    di as error "Run tmr-visit-map-audit-v1.do; complete the draft event map first."
    exit 601
}
tempfile visitmap
preserve
    import delimited using `"`tmr_map'"', clear varnames(1) stringcols(_all)
    foreach v in redcap_event_name repeat_instance planned_visit display_order visit_label {
        confirm variable `v'
    }
    replace redcap_event_name = strtrim(redcap_event_name)
    foreach v in repeat_instance planned_visit display_order {
        destring `v', replace
    }
    replace repeat_instance = 0 if missing(repeat_instance)
    assert repeat_instance >= 0 & repeat_instance == floor(repeat_instance)
    assert inrange(planned_visit,0,20) & planned_visit == floor(planned_visit) if !missing(planned_visit)
    assert display_order == planned_visit if planned_visit > 0 & !missing(planned_visit)
    assert !missing(display_order) & strtrim(visit_label) != "" if !missing(planned_visit)
    assert !inlist(display_order,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20) if planned_visit == 0
    assert display_order > 1 & display_order < 21 if planned_visit == 0
    isid redcap_event_name repeat_instance
    keep redcap_event_name repeat_instance planned_visit display_order visit_label
    save `visitmap'
restore
merge m:1 redcap_event_name repeat_instance using `visitmap', keep(master match) gen(_visit_map_merge)
quietly count if has_pmeas == 1 & (_visit_map_merge != 3 | missing(planned_visit))
if r(N) > 0 {
    di as error "Unmapped measurement rows: " r(N)
    list record_id redcap_event_name repeat_instance prog_visit_date ///
        if has_pmeas == 1 & (_visit_map_merge != 3 | missing(planned_visit)), noobs
    di as error "Complete the event map. No report has been generated."
    exit 459
}
drop _visit_map_merge

** One key per scheduled visit; each optional event/instance has its own key.
gen str160 report_visit_key = "P" + string(planned_visit,"%02.0f") if planned_visit > 0 & !missing(planned_visit)
replace report_visit_key = "O:" + redcap_event_name + ":" + string(repeat_instance,"%09.0f") if planned_visit == 0
assert strlen(redcap_event_name) <= 120 if has_pmeas == 1

** Multiple instruments may share a visit. Conflicting outcome values must be
** resolved explicitly: max()/mean() must not choose an individual's response.
foreach v in weight hba1c diabetes_meds visit_date_cm {
    capture confirm variable `v'
    if !_rc {
        bysort record_id report_visit_key: egen _visit_min = min(`v') if has_pmeas == 1
        bysort record_id report_visit_key: egen _visit_max = max(`v') if has_pmeas == 1
        quietly count if _visit_min != _visit_max & !missing(_visit_min,_visit_max)
        if r(N) > 0 {
            di as error "Conflicting `v' within a planned/optional visit."
            list record_id redcap_event_name repeat_instance `v' if _visit_min != _visit_max & !missing(_visit_min,_visit_max), noobs
            exit 459
        }
        drop _visit_min _visit_max
    }
}
bysort record_id report_visit_key: egen _visit_order_min = min(display_order) if has_pmeas == 1
bysort record_id report_visit_key: egen _visit_order_max = max(display_order) if has_pmeas == 1
assert _visit_order_min == _visit_order_max if has_pmeas == 1
drop _visit_order_min _visit_order_max

** The v2 dataset is separate from legacy prepared data. Existing DQ/report
** scripts continue to use the legacy file and are not switched implicitly.
gen byte prog_visit_num = planned_visit if planned_visit > 0 & !missing(planned_visit)
label variable prog_visit_num "Planned visit from REDCap event mapping; optional visits missing"
gen byte prog_visit_block = .
gen byte prog_visit_inblock = .
replace prog_visit_block = 1 if prog_visit_num == 1
replace prog_visit_inblock = 0 if prog_visit_num == 1
replace prog_visit_block = 2 if inrange(prog_visit_num,2,7)
replace prog_visit_inblock = prog_visit_num - 1 if inrange(prog_visit_num,2,7)
replace prog_visit_block = 3 if inrange(prog_visit_num,8,11)
replace prog_visit_inblock = prog_visit_num - 7 if inrange(prog_visit_num,8,11)
replace prog_visit_block = 4 if inrange(prog_visit_num,12,16)
replace prog_visit_inblock = prog_visit_num - 11 if inrange(prog_visit_num,12,16)
replace prog_visit_block = 5 if inrange(prog_visit_num,17,20)
replace prog_visit_inblock = prog_visit_num - 16 if inrange(prog_visit_num,17,20)
label define prog_visit_block_lbl 1 "Baseline" 2 "TMR phase" 3 "Food reintroduction phase" 4 "Year 1 maintenance phase" 5 "Year 2 maintenance phase", replace
label values prog_visit_block prog_visit_block_lbl
gen byte prog_visit_label = prog_visit_num
label define prog_visit_label_lbl ///
    1 "Baseline" ///
    2 "TMR visit 1" ///
    3 "TMR visit 2" ///
    4 "TMR visit 3" ///
    5 "TMR visit 4" ///
    6 "TMR visit 5" ///
    7 "TMR visit 6" ///
    8 "Food visit 1" ///
    9 "Food visit 2" ///
    10 "Food visit 3" ///
    11 "Food visit 4" ///
    12 "Year 1 weight visit 1" ///
    13 "Year 1 weight visit 2" ///
    14 "Year 1 weight visit 3" ///
    15 "Year 1 weight visit 4" ///
    16 "Year 1 weight visit 5" ///
    17 "Year 2 weight visit 1" ///
    18 "Year 2 weight visit 2" ///
    19 "Year 2 weight visit 3" ///
    20 "Year 2 weight visit 4", replace
label values prog_visit_label prog_visit_label_lbl
foreach phase in baseline tmr food year1 year2 {
    gen byte is_`phase' = .
}
replace is_baseline = prog_visit_num == 1 if !missing(prog_visit_num)
replace is_tmr = inrange(prog_visit_num,2,7) if !missing(prog_visit_num)
replace is_food = inrange(prog_visit_num,8,11) if !missing(prog_visit_num)
replace is_year1 = inrange(prog_visit_num,12,16) if !missing(prog_visit_num)
replace is_year2 = inrange(prog_visit_num,17,20) if !missing(prog_visit_num)

** Medication count category (3 = 3+, not an exact medication count).
confirm numeric variable diabetes_meds
assert inrange(diabetes_meds,1,6) & diabetes_meds == floor(diabetes_meds) if !missing(diabetes_meds)
gen byte meds_count_category = .
replace meds_count_category = 0 if inlist(diabetes_meds,5,6)
replace meds_count_category = 1 if inlist(diabetes_meds,1,2)
replace meds_count_category = 2 if diabetes_meds == 3
replace meds_count_category = 3 if diabetes_meds == 4
label define meds_count_category_lbl 0 "0" 1 "1" 2 "2" 3 "3+", replace
label values meds_count_category meds_count_category_lbl
label variable meds_count_category "Medication count category (upper category 3+)"
bysort record_id: egen baseline_meds_category = max(cond(prog_visit_num == 1,meds_count_category,.))
label values baseline_meds_category meds_count_category_lbl


** =========================================================================
** PART 10. CORE ANALYSIS DERIVED VARIABLES
** =========================================================================


** -------------------------------------------------------------------------
** Average blood pressure
**
** For programme analyses, average SBP and DBP are based on readings 2 and 3.
** If one of readings 2 or 3 is present, the average equals the available
** reading. If both are missing, the average is missing.
** -------------------------------------------------------------------------

capture confirm variable sbp_avg
if !_rc {
    drop sbp_avg
}

capture confirm variable dbp_avg
if !_rc {
    drop dbp_avg
}

capture confirm variable sbp2
local has_sbp2 = !_rc
capture confirm variable sbp3
local has_sbp3 = !_rc

if `has_sbp2' == 1 | `has_sbp3' == 1 {
    egen sbp_avg = rowmean(sbp2 sbp3)
    label variable sbp_avg "Analysis: average systolic BP from readings 2 and 3"
}

capture confirm variable dbp2
local has_dbp2 = !_rc
capture confirm variable dbp3
local has_dbp3 = !_rc

if `has_dbp2' == 1 | `has_dbp3' == 1 {
    egen dbp_avg = rowmean(dbp2 dbp3)
    label variable dbp_avg "Analysis: average diastolic BP from readings 2 and 3"
}


** -------------------------------------------------------------------------
** Participant-level baseline date and baseline values
**
** Baseline is the explicitly mapped baseline event (planned visit 1).
**
** For outcomes, the baseline value is the non-missing value recorded on the
** baseline programme visit. If duplicate baseline rows exist, max() is used
** as a simple deterministic aggregator after filtering to the baseline row.
** -------------------------------------------------------------------------

bysort record_id: egen _baseline_core_date = min(cond(prog_visit_num == 1, visit_date_cm, .))
bysort record_id: egen _baseline_any_date = min(cond(prog_visit_num == 1, prog_visit_date, .))
gen baseline_prog_date = _baseline_core_date
replace baseline_prog_date = _baseline_any_date if missing(baseline_prog_date)
drop _baseline_core_date _baseline_any_date
format baseline_prog_date %dM_d,_CY
label variable baseline_prog_date "Analysis: baseline programme date"

local baseline_outcomes ///
    weight ///
    waist ///
    hip ///
    sbp_avg ///
    dbp_avg ///
    glucose ///
    hba1c ///
    hba1c_copy ///
    alt ///
    ast ///
    alp ///
    bilirubin_total ///
    albumin ///
    protein_total ///
    ggt ///
    hb ///
    cholesterol_total ///
    cholesterol_hdl ///
    cholesterol_ldl ///
    triglyceride ///
    sodium ///
    potassium ///
    urea ///
    creatinine ///
    egfr ///
    eq_vas

foreach v of local baseline_outcomes {

    capture confirm variable `v'

    if !_rc {

        capture drop baseline_`v'
        gen _baseline_`v' = `v' if prog_visit_num == 1 & !missing(`v')
        bysort record_id: egen baseline_`v' = max(_baseline_`v')
        drop _baseline_`v'

        label variable baseline_`v' "Analysis: baseline `v'"
    }
}


** -------------------------------------------------------------------------
** Change from baseline for common continuous outcomes
**
** These are created only where both current and baseline values exist.
** Percentage change is calculated only when the baseline value is positive.
** -------------------------------------------------------------------------

local change_outcomes ///
    weight ///
    waist ///
    hip ///
    sbp_avg ///
    dbp_avg ///
    glucose ///
    hba1c ///
    hba1c_copy ///
    alt ///
    ast ///
    alp ///
    bilirubin_total ///
    albumin ///
    protein_total ///
    ggt ///
    hb ///
    cholesterol_total ///
    cholesterol_hdl ///
    cholesterol_ldl ///
    triglyceride ///
    sodium ///
    potassium ///
    urea ///
    creatinine ///
    egfr ///
    eq_vas

foreach v of local change_outcomes {

    capture confirm variable `v'
    local has_v = !_rc

    capture confirm variable baseline_`v'
    local has_baseline = !_rc

    if `has_v' == 1 & `has_baseline' == 1 {

        capture drop change_`v'_abs
        capture drop change_`v'_pct

        gen change_`v'_abs = `v' - baseline_`v'
        gen change_`v'_pct = 100 * (`v' - baseline_`v') / baseline_`v' if baseline_`v' > 0

        label variable change_`v'_abs "Analysis: absolute change in `v' from baseline"
        label variable change_`v'_pct "Analysis: percentage change in `v' from baseline"
    }
}


** -------------------------------------------------------------------------
** Time since programme baseline
**
** Programme time is calculated from the baseline programme date. Weeks are
** rounded to the nearest whole week because participants may not attend on
** exactly the scheduled day.
** -------------------------------------------------------------------------

gen days_from_baseline = prog_visit_date - baseline_prog_date
gen weeks_from_baseline = round(days_from_baseline / 7)

label variable days_from_baseline "Analysis: days from programme baseline"
label variable weeks_from_baseline "Analysis: rounded weeks from programme baseline"


** =========================================================================
** PART 11. ORDER VARIABLES FOR ANALYSIS
** =========================================================================


** -------------------------------------------------------------------------
** Place analysis variables near the front of the dataset
**
** Raw REDCap variables are retained. The new analysis variables are ordered
** first so analysts can find them quickly.
** -------------------------------------------------------------------------

order ///
    record_id ///
    redcap_event_name ///
    redcap_repeat_instrument ///
    redcap_repeat_instance ///
    redcap_data_access_group ///
    analysis_arm ///
    has_scr ///
    has_scr1 ///
    has_scr2 ///
    scr_stage ///
    p_has_scr ///
    p_has_scr1 ///
    p_has_scr2 ///
    has_prog ///
    has_padmin ///
    has_pmeas ///
    has_pwd ///
    has_pae ///
    p_has_prog ///
    p_has_padmin ///
    p_has_pmeas ///
    p_has_pwd ///
    p_has_pae ///
    prog_visit_date ///
    prog_visit_num ///
    prog_visit_block ///
    prog_visit_inblock ///
    prog_visit_label ///
    is_baseline ///
    is_tmr ///
    is_food ///
    is_year1 ///
    is_year2 ///
    baseline_prog_date ///
    days_from_baseline ///
    weeks_from_baseline, first


** =========================================================================
** PART 12. SIMPLE CHECKS
** =========================================================================


** -------------------------------------------------------------------------
** Basic dataset checks
** -------------------------------------------------------------------------

di as text "------------------------------------------------------------"
di as text "Basic analysis-preparation checks"
di as text "------------------------------------------------------------"

count
di as result "Rows in prepared full analysis dataset: " r(N)

quietly levelsof record_id, local(record_ids)
local n_records : word count `record_ids'
di as result "Number of unique record_id values: `n_records'"

tab analysis_arm, missing
tab scr_stage, missing
tab prog_visit_block, missing
tab prog_visit_label, missing


** -------------------------------------------------------------------------
** Review rows not assigned to screening or programme arm
**
** These may be empty REDCap rows or future instruments that need adding to
** this preparation do-file.
** -------------------------------------------------------------------------

count if analysis_arm == 4
di as text "Rows not assigned to screening or programme arm: " as result r(N)

if r(N) > 0 {
    list record_id redcap_event_name redcap_repeat_instrument redcap_repeat_instance ///
        if analysis_arm == 4 in 1/20, abbreviate(20)
}


** -------------------------------------------------------------------------
** Review programme visit counts
** -------------------------------------------------------------------------

di as text "Programme visit counts by planned visit label"
tab prog_visit_label if has_pmeas == 1, missing


** -------------------------------------------------------------------------
** Describe key derived analysis variables
** -------------------------------------------------------------------------

describe ///
    analysis_arm ///
    scr_stage ///
    prog_visit_date ///
    prog_visit_num ///
    prog_visit_block ///
    prog_visit_inblock ///
    prog_visit_label ///
    baseline_prog_date ///
    days_from_baseline ///
    weeks_from_baseline


** =========================================================================
** PART 13. SAVE ANALYSIS-PREPARED DATASET
** =========================================================================


** -------------------------------------------------------------------------
** Save with datestamp and stable latest copy
**
** The dated file preserves each prepared version.
** The latest file gives future analysis/report scripts a stable input path.
** -------------------------------------------------------------------------

compress

save "`clean_dta_dated'", replace

di as result "Dated full analysis-prepared dataset saved:"
di as result "`clean_dta_dated'"

save "`clean_dta_latest'", replace

di as result "Latest full analysis-prepared dataset saved:"
di as result "`clean_dta_latest'"

capture log close

