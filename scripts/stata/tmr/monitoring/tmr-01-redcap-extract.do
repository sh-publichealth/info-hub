** HEADER -----------------------------------------------------
**  DO-FILE METADATA
    //  algorithm name             tmr-01-redcap-extract.do
    //  project:                   SH007 total meal replacement
    //  analysts:                  Ian HAMBLETON
    //  date last modified         14-Aug-2026
    //  workflow step              1 of 4
    //  algorithm task             Extract the full TMR REDCap database and
    //                              create the participant recruitment/status
    //                              dataset used by downstream reports

    ** General algorithm set-up
    version 19
    clear all
    macro drop _all
    set more off
    set linesize 80

    ** Folder locations
    global projectroot "C:\yoshimi-hot\output\analyse-sth\sh007-total-meal-replacement\stata"
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
    log using "$log\tmr-01-redcap-extract", replace
** HEADER -----------------------------------------------------


** -------------------------------------------------------------------------
** REDCap API settings
**
** USER EDIT REQUIRED:
**
** Paste the project-specific REDCap API token below.
**
** The API location is:
**     https://caribdata.org/redcap/api/
**
** SECURITY NOTE:
** For this first implementation, the token can be pasted into the do-file.
** Longer term, it would be safer to store the token in a local text file
** outside the project folder and read it into Python.
** -------------------------------------------------------------------------

local api_url   "https://caribdata.org/redcap/api/"
local api_token "31AFA892A06053379609767FEA8757B4"


** -------------------------------------------------------------------------
** Create dated output filenames
**
** The raw API export will be saved as a dated CSV file.
** A raw Stata .dta copy will also be saved.
**
** A stable "latest" Stata copy will also be saved so that other scripts can
** always refer to the same filename.
** -------------------------------------------------------------------------

local today = c(current_date)
local today_file = subinstr("`today'", " ", "_", .)
local today_file = subinstr("`today_file'", "-", "_", .)

local raw_csv_dated "$rawdir\tmr_full_redcap_api_extract_`today_file'.csv"
local raw_dta_dated "$rawdir\tmr_full_redcap_api_extract_`today_file'.dta"
local raw_dta_latest "$rawdir\tmr_full_redcap_api_extract_latest.dta"


** -------------------------------------------------------------------------
** Preferred variable order
**
** This is the variable order from the full manual REDCap export do-file.
**
** IMPORTANT:
** The following four variables are REDCap metadata columns:
**
**     redcap_event_name
**     redcap_repeat_instrument
**     redcap_repeat_instance
**     redcap_data_access_group
**
** They should NOT be requested through an API fields[] list. In this script
** we are not sending any fields[] list at all, so REDCap should export the
** full database and include metadata columns where appropriate.
** -------------------------------------------------------------------------

local preferred_order ///
    record_id ///
    redcap_event_name ///
    redcap_repeat_instrument ///
    redcap_repeat_instance ///
    redcap_data_access_group ///
    date_screen_1 ///
    emis_id_screen_1 ///
    fname_screen_1 ///
    lname_screen_1 ///
    sex_screen_1 ///
    phone_screen_1 ///
    phone2_screen_1 ///
    phone3_screen_1 ///
    email_screen_1 ///
    email2_screen_1 ///
    vstatus_screen_1 ///
    dod_screen_1 ///
    diab_type_screen_1 ///
    dob_screen_1 ///
    date_dx_screen_1 ///
    date_hba1c_screen_1 ///
    hba1c_screen_1 ///
    date_rx_screen_1 ///
    date_ref_screen_1 ///
    age_screen_1 ///
    ddur_screen_1 ///
    ddur_screen_1_asi ///
    interested_screen_1 ///
    emis_id_screen_2 ///
    fname_screen_2 ///
    lname_screen_2 ///
    sex_screen_2 ///
    phone_screen_2 ///
    phone2_screen_2 ///
    phone3_screen_2 ///
    email_screen_2 ///
    email2_screen_2 ///
    date_dx_screen_2 ///
    date_screen_2 ///
    dobsame_screen_2 ///
    dob_screen_2 ///
    age_screen_2 ///
    exclusion_screen_2 ///
    height_screen_2 ///
    weight_screen_2 ///
    bmi_screen_2 ///
    diagnosis_ed_screen_2 ///
    type_ed_screen_2 ///
    type_ed_oth_screen_2 ///
    des_q1_screen_2 ///
    des_q1a_screen_2 ///
    des_q1b_screen_2 ///
    des_q1c_screen_2 ///
    score_q1_no_screen_2 ///
    score_q1_yes_screen_2 ///
    des_q2_screen_2 ///
    des_q3_screen_2 ///
    des_q4_screen_2 ///
    des_score_screen_2 ///
    group_screen_2 ///
    interested_screen_2 ///
    emis_id_padmin ///
    fname_padmin ///
    lname_padmin ///
    sex_padmin ///
    dob_padmin ///
    phone_padmin ///
    phone2_padmin ///
    phone3_padmin ///
    email_padmin ///
    email2_padmin ///
    date_dx_padmin ///
    height_padmin ///
    site ///
    preferred_location ///
    consent_obtained ///
    consent_date ///
    consent_form ///
    participant_admin_complete ///
    visit_date_cm ///
    weight ///
    waist ///
    hip ///
    sbp1 ///
    dbp1 ///
    sbp2 ///
    dbp2 ///
    sbp3 ///
    dbp3 ///
    glucose ///
    diabetes_meds ///
    hypertension_meds ///
    smoking ///
    smoking_past ///
    core_measurements_complete ///
    visit_date_anth ///
    anthropometry_complete ///
    visit_date_hba1c ///
    hba1c ///
    hba1c_complete ///
    visit_date_lm ///
    results_date ///
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
    lab_measurements_complete ///
    visit_date_em ///
    fibroscan_date ///
    lsm_kpa ///
    lsm_iqr ///
    cap_dbm ///
    cap_sd ///
    eq_mob ///
    eq_sc ///
    eq_ua ///
    eq_pd ///
    eq_ad ///
    eq_vas ///
    paid01 ///
    paid02 ///
    paid03 ///
    paid04 ///
    paid05 ///
    paid06 ///
    paid07 ///
    paid08 ///
    paid09 ///
    paid10 ///
    paid11 ///
    paid12 ///
    paid13 ///
    paid14 ///
    paid15 ///
    paid16 ///
    paid17 ///
    paid18 ///
    paid19 ///
    paid20 ///
    ipaq_walk_days ///
    ipaq_walk_mins ///
    ipaq_mod_days ///
    ipaq_mod_mins ///
    ipaq_vig_days ///
    ipaq_vig_mins ///
    ipaq_sit_mins ///
    expanded_measurements_complete ///
    visit_date_he ///
    he_currency ///
    he_currency_oth ///
    he_insulin_supplied ///
    he_metformin_supplied ///
    he_antihyp_supplied ///
    he_notes ///
    health_economics_complete ///
    study_id_withdrawal ///
    date_withdrawal ///
    phase_withdrawal ///
    type_withdrawal ///
    reason_withdrawal ///
    reason_withdrawal_oth ///
    ae_withdrawal_rpt ///
    dlc_withdrawal ///
    initiated_withdrawal ///
    withdrawal_form_complete ///
    study_id_ae ///
    date_ae ///
    notes_ae ///
    class_ae ///
    adverse_event_complete


** -------------------------------------------------------------------------
** Known REDCap date variables
**
** These date variables are converted from REDCap YMD strings into Stata
** daily dates after import.
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


** -------------------------------------------------------------------------
** Run Python inside Stata to call the REDCap API
**
** This block requests the FULL database.
**
** This script does not send fields[0], fields[1], etc. If no fields[] list is sent, REDCap exports all available
** fields for the project, subject to the API user's permissions.
**
** This requires:
**     - Stata Python integration
**     - Python package: requests
** -------------------------------------------------------------------------

python:
from sfi import Macro
from pathlib import Path
import requests

# -------------------------------------------------------------------------
# Read values passed from Stata locals/macros
# -------------------------------------------------------------------------

api_url = Macro.getLocal("api_url")
api_token = Macro.getLocal("api_token")
raw_csv = Macro.getLocal("raw_csv_dated")

# -------------------------------------------------------------------------
# Basic checks before contacting REDCap
# -------------------------------------------------------------------------

if not api_url:
    raise ValueError("api_url is empty. Please check the Stata local api_url.")

if not api_token or "PASTE-YOUR-REDCAP-PROJECT-API-TOKEN-HERE" in api_token:
    raise ValueError("Please edit local api_token before running this do-file.")

out_path = Path(raw_csv)
out_path.parent.mkdir(parents=True, exist_ok=True)

# -------------------------------------------------------------------------
# Build REDCap API request
#
# Key choices:
#
#     content = record
#         Export project records.
#
#     format = csv
#         Return a CSV file that Stata can import easily.
#
#     type = flat
#         Return a flat table.
#
#     rawOrLabel = raw
#         Export coded values rather than value labels.
#
#     rawOrLabelHeaders = raw
#         Export raw REDCap variable names as column headers.
#
#     exportDataAccessGroups = true
#         Ask REDCap to include the data access group column, where available.
#
#     exportSurveyFields = false
#         Do not add REDCap survey identifier/timestamp fields.
#
#     returnFormat = json
#         Ask REDCap to return API errors in JSON format.
#
# IMPORTANT:
#     No fields[] parameters are included. This requests the whole database.
# -------------------------------------------------------------------------

payload = {
    "token": api_token,
    "content": "record",
    "format": "csv",
    "type": "flat",
    "csvDelimiter": "",
    "rawOrLabel": "raw",
    "rawOrLabelHeaders": "raw",
    "exportCheckboxLabel": "false",
    "exportSurveyFields": "false",
    "exportDataAccessGroups": "true",
    "returnFormat": "json"
}

# -------------------------------------------------------------------------
# Call the API
# -------------------------------------------------------------------------

try:
    response = requests.post(api_url, data=payload, timeout=180)
except requests.exceptions.RequestException as exc:
    raise RuntimeError(f"Could not contact REDCap API: {exc}")

try:
    response.raise_for_status()
except requests.exceptions.HTTPError as exc:
    msg = response.text[:1500]
    raise RuntimeError(
        f"REDCap API returned an HTTP error: {exc}\n"
        f"Response text:\n{msg}"
    )

# -------------------------------------------------------------------------
# Basic content checks
# -------------------------------------------------------------------------

content_text = response.text

if "record_id" not in content_text[:1000]:
    msg = content_text[:1500]
    raise RuntimeError(
        "The API response did not look like the expected CSV export. "
        "Check the API URL, token, user rights, and project export settings.\n\n"
        f"First part of response:\n{msg}"
    )

# -------------------------------------------------------------------------
# Save raw CSV exactly as returned by REDCap
# -------------------------------------------------------------------------

out_path.write_text(content_text, encoding="utf-8-sig")

print(f"Full REDCap API export saved to: {out_path}")
end


** -------------------------------------------------------------------------
** Confirm that the raw CSV was created
** -------------------------------------------------------------------------

capture confirm file "`raw_csv_dated'"
if _rc {
    di as error "The expected REDCap API export was not created:"
    di as error "`raw_csv_dated'"
    exit 601
}

di as result "Full raw REDCap API export created:"
di as result "`raw_csv_dated'"


** -------------------------------------------------------------------------
** Import the REDCap API CSV into Stata
**
** The API export should contain column headers, so we use varnames(1).
**
** We initially import all columns as strings to protect:
**     - IDs with leading zeroes
**     - date strings
**     - occasional mixed REDCap content
** -------------------------------------------------------------------------

import delimited using "`raw_csv_dated'", clear varnames(1) bindquote(strict) stringcols(_all)


** -------------------------------------------------------------------------
** Basic checks immediately after import
** -------------------------------------------------------------------------

describe

capture confirm variable record_id
if _rc {
    di as error "record_id was not found after import. Check the REDCap API export."
    exit 111
}

count
di as result "Number of rows imported from full REDCap API export: " r(N)


** -------------------------------------------------------------------------
** Ensure expected REDCap metadata columns exist
**
** These four variables are REDCap metadata columns, not project fields.
** If REDCap does not return one of them, we create a blank string version so
** that downstream scripts can rely on the variable existing.
** -------------------------------------------------------------------------

foreach v in redcap_event_name redcap_repeat_instrument redcap_repeat_instance redcap_data_access_group {
    capture confirm variable `v'
    if !_rc {
        di as result "REDCap metadata column returned: `v'"
    }
    else {
        di as text "REDCap metadata column not returned, creating blank variable: `v'"
        gen str1 `v' = ""
    }
}


** -------------------------------------------------------------------------
** Convert known date variables from REDCap YMD strings to Stata dates
**
** The manual REDCap export do-file converted these date variables one by one.
** This API version uses a loop over the same date variable list.
** -------------------------------------------------------------------------

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


** -------------------------------------------------------------------------
** Destring variables where possible
**
** We imported all variables as strings for safety. After date conversion, this
** loop attempts to destring any remaining string variables that contain only
** numeric values.
**
** Non-numeric string variables such as names, email addresses, notes, and IDs
** are left unchanged.
** -------------------------------------------------------------------------

ds, has(type string)
local string_vars `r(varlist)'

foreach v of local string_vars {
    capture destring `v', replace ignore(" ")
}


** -------------------------------------------------------------------------
** Value labels
**
** These match the value labels from the manual full export do-file.
** -------------------------------------------------------------------------

label define sex_screen_1_ 1 "Female" 2 "Male", replace
label define vstatus_screen_1_ 1 "Alive" 2 "Dead", replace
label define diab_type_screen_1_ 1 "Type 1" 2 "Type 2" 3 "Gestational", replace
label define interested_screen_1_ 1 "Interested" 2 "Possibly interested" 3 "Not interested", replace
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
label define eq_mob_ 1 "No problems" 2 "Some problems" 3 "Extreme problems", replace
label define eq_sc_ 1 "No problems" 2 "Some problems" 3 "Extreme problems", replace
label define eq_ua_ 1 "No problems" 2 "Some problems" 3 "Extreme problems", replace
label define eq_pd_ 1 "No problems" 2 "Some problems" 3 "Extreme problems", replace
label define eq_ad_ 1 "No problems" 2 "Some problems" 3 "Extreme problems", replace
label define paid01_ 0 "Not a problem" 1 "Minor problem" 2 "Moderate problem" 3 "Somewhat serious problem" 4 "Serious problem", replace
label define paid02_ 0 "Not a problem" 1 "Minor problem" 2 "Moderate problem" 3 "Somewhat serious problem" 4 "Serious problem", replace
label define paid03_ 0 "Not a problem" 1 "Minor problem" 2 "Moderate problem" 3 "Somewhat serious problem" 4 "Serious problem", replace
label define paid04_ 0 "Not a problem" 1 "Minor problem" 2 "Moderate problem" 3 "Somewhat serious problem" 4 "Serious problem", replace
label define paid05_ 0 "Not a problem" 1 "Minor problem" 2 "Moderate problem" 3 "Somewhat serious problem" 4 "Serious problem", replace
label define paid06_ 0 "Not a problem" 1 "Minor problem" 2 "Moderate problem" 3 "Somewhat serious problem" 4 "Serious problem", replace
label define paid07_ 0 "Not a problem" 1 "Minor problem" 2 "Moderate problem" 3 "Somewhat serious problem" 4 "Serious problem", replace
label define paid08_ 0 "Not a problem" 1 "Minor problem" 2 "Moderate problem" 3 "Somewhat serious problem" 4 "Serious problem", replace
label define paid09_ 0 "Not a problem" 1 "Minor problem" 2 "Moderate problem" 3 "Somewhat serious problem" 4 "Serious problem", replace
label define paid10_ 0 "Not a problem" 1 "Minor problem" 2 "Moderate problem" 3 "Somewhat serious problem" 4 "Serious problem", replace
label define paid11_ 0 "Not a problem" 1 "Minor problem" 2 "Moderate problem" 3 "Somewhat serious problem" 4 "Serious problem", replace
label define paid12_ 0 "Not a problem" 1 "Minor problem" 2 "Moderate problem" 3 "Somewhat serious problem" 4 "Serious problem", replace
label define paid13_ 0 "Not a problem" 1 "Minor problem" 2 "Moderate problem" 3 "Somewhat serious problem" 4 "Serious problem", replace
label define paid14_ 0 "Not a problem" 1 "Minor problem" 2 "Moderate problem" 3 "Somewhat serious problem" 4 "Serious problem", replace
label define paid15_ 0 "Not a problem" 1 "Minor problem" 2 "Moderate problem" 3 "Somewhat serious problem" 4 "Serious problem", replace
label define paid16_ 0 "Not a problem" 1 "Minor problem" 2 "Moderate problem" 3 "Somewhat serious problem" 4 "Serious problem", replace
label define paid17_ 0 "Not a problem" 1 "Minor problem" 2 "Moderate problem" 3 "Somewhat serious problem" 4 "Serious problem", replace
label define paid18_ 0 "Not a problem" 1 "Minor problem" 2 "Moderate problem" 3 "Somewhat serious problem" 4 "Serious problem", replace
label define paid19_ 0 "Not a problem" 1 "Minor problem" 2 "Moderate problem" 3 "Somewhat serious problem" 4 "Serious problem", replace
label define paid20_ 0 "Not a problem" 1 "Minor problem" 2 "Moderate problem" 3 "Somewhat serious problem" 4 "Serious problem", replace
label define expanded_measurements_complete_ 0 "Incomplete" 1 "Unverified" 2 "Complete", replace
label define he_currency_ 1 "GBP" 2 "ZAR" 3 "Other", replace
label define health_economics_complete_ 0 "Incomplete" 1 "Unverified" 2 "Complete", replace
label define phase_withdrawal_ 1 "TDR" 2 "food reintroduction" 3 "maintenance", replace
label define type_withdrawal_ 1 "Yes" 2 "No" 3 "Maybe", replace
label define reason_withdrawal_ 1 "Medical / adverse effects" 2 "Programme burden (time, logistics, products)" 3 "Psychological or social reasons" 4 "Loss of motivation / preference change" 5 "Competing illness or life event" 6 "Moved away / unavailable" 7 "Participant died" 8 "Other (specify)", replace
label define ae_withdrawal_rpt_ 1 "Yes" 2 "No", replace
label define initiated_withdrawal_ 1 "participant" 2 "service", replace
label define withdrawal_form_complete_ 0 "Incomplete" 1 "Unverified" 2 "Complete", replace
label define class_ae_ 1 "adverse event" 2 "serious adverse event", replace
label define adverse_event_complete_ 0 "Incomplete" 1 "Unverified" 2 "Complete", replace


** -------------------------------------------------------------------------
** Attach value labels where the relevant variables exist
** -------------------------------------------------------------------------

capture label values sex_screen_1 sex_screen_1_
capture label values vstatus_screen_1 vstatus_screen_1_
capture label values diab_type_screen_1 diab_type_screen_1_
capture label values interested_screen_1 interested_screen_1_
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
capture label values eq_mob eq_mob_
capture label values eq_sc eq_sc_
capture label values eq_ua eq_ua_
capture label values eq_pd eq_pd_
capture label values eq_ad eq_ad_
capture label values paid01 paid01_
capture label values paid02 paid02_
capture label values paid03 paid03_
capture label values paid04 paid04_
capture label values paid05 paid05_
capture label values paid06 paid06_
capture label values paid07 paid07_
capture label values paid08 paid08_
capture label values paid09 paid09_
capture label values paid10 paid10_
capture label values paid11 paid11_
capture label values paid12 paid12_
capture label values paid13 paid13_
capture label values paid14 paid14_
capture label values paid15 paid15_
capture label values paid16 paid16_
capture label values paid17 paid17_
capture label values paid18 paid18_
capture label values paid19 paid19_
capture label values paid20 paid20_
capture label values expanded_measurements_complete expanded_measurements_complete_
capture label values he_currency he_currency_
capture label values health_economics_complete health_economics_complete_
capture label values phase_withdrawal phase_withdrawal_
capture label values type_withdrawal type_withdrawal_
capture label values reason_withdrawal reason_withdrawal_
capture label values ae_withdrawal_rpt ae_withdrawal_rpt_
capture label values initiated_withdrawal initiated_withdrawal_
capture label values withdrawal_form_complete withdrawal_form_complete_
capture label values class_ae class_ae_
capture label values adverse_event_complete adverse_event_complete_


** -------------------------------------------------------------------------
** Variable labels
**
** This section uses the most operationally important labels from the manual
** import file. Additional labels can be added later if required, but the
** variable names and value labels are preserved in this raw full extract.
** -------------------------------------------------------------------------

capture label variable record_id "Participant Study ID"
capture label variable redcap_event_name "Event Name"
capture label variable redcap_repeat_instrument "Repeat Instrument"
capture label variable redcap_repeat_instance "Repeat Instance"
capture label variable redcap_data_access_group "Data Access Group"
capture label variable date_screen_1 "Date of screening"
capture label variable emis_id_screen_1 "EMIS ID"
capture label variable fname_screen_1 "First Name"
capture label variable lname_screen_1 "Last Name"
capture label variable sex_screen_1 "Participant sex"
capture label variable phone_screen_1 "Phone number #1"
capture label variable phone2_screen_1 "Phone number #2"
capture label variable phone3_screen_1 "Phone number #3"
capture label variable email_screen_1 "Email address #1"
capture label variable email2_screen_1 "Email address #2"
capture label variable vstatus_screen_1 "Vital Status"
capture label variable dod_screen_1 "Date of death"
capture label variable diab_type_screen_1 "Diabetes Type"
capture label variable dob_screen_1 "Date of birth"
capture label variable date_dx_screen_1 "Date of diabetes diagnosis"
capture label variable date_hba1c_screen_1 "Date of last known HbA1c test"
capture label variable hba1c_screen_1 "HbA1c result"
capture label variable date_rx_screen_1 "Date of last known diabetes prescription"
capture label variable date_ref_screen_1 "Study Reference Date: 28 Feb 2026"
capture label variable age_screen_1 "Age (auto-calculated)"
capture label variable ddur_screen_1 "Duration of diabetes YEARS"
capture label variable ddur_screen_1_asi "Duration of diabetes YEARS"
capture label variable interested_screen_1 "Are you interested in taking part in the TMR pilot?"
capture label variable emis_id_screen_2 "EMIS ID"
capture label variable fname_screen_2 "First Name"
capture label variable lname_screen_2 "Last Name"
capture label variable sex_screen_2 "Participant sex"
capture label variable dob_screen_2 "Date of birth"
capture label variable date_screen_2 "Date of screening"
capture label variable date_dx_screen_2 "Date of diabetes diagnosis"
capture label variable age_screen_2 "Age (auto-calculated)"
capture label variable height_screen_2 "Height (cm)?"
capture label variable weight_screen_2 "Weight (kg)?"
capture label variable bmi_screen_2 "Body Mass Index (kg/m2) (auto-calculated)"
capture label variable group_screen_2 "Group"
capture label variable interested_screen_2 "Are you interested in taking part in the TMR pilot?"
capture label variable emis_id_padmin "EMIS ID"
capture label variable fname_padmin "First Name"
capture label variable lname_padmin "Last Name"
capture label variable sex_padmin "Participant sex"
capture label variable dob_padmin "Date of birth"
capture label variable phone_padmin "Phone number #1"
capture label variable phone2_padmin "Phone number #2"
capture label variable phone3_padmin "Phone number #3"
capture label variable email_padmin "Email address #1"
capture label variable email2_padmin "Email address #2"
capture label variable date_dx_padmin "Date of diabetes diagnosis"
capture label variable height_padmin "Height (cm)?"
capture label variable site "Study site"
capture label variable preferred_location "Participants preferred clinic location"
capture label variable consent_obtained "Was informed consent obtained?"
capture label variable consent_date "Date informed consent obtained"
capture label variable consent_form "Please upload signed consent form"
capture label variable participant_admin_complete "Complete?"
capture label variable visit_date_cm "Date of measurement"
capture label variable weight "Weight (kg)?"
capture label variable waist "Waist circumference (cm)?"
capture label variable hip "Hip circumference (cm)?"
capture label variable sbp1 "Reading 1 Systolic blood pressure(mmHg)? "
capture label variable dbp1 "Reading 1 Diastolic blood pressure(mmHg)?"
capture label variable sbp2 "Reading 2 Systolic blood pressure (mmHg)? "
capture label variable dbp2 "Reading 2 Diastolic blood pressure (mmHg)?"
capture label variable sbp3 "Reading 3 Systolic blood pressure (mmHg)? "
capture label variable dbp3 "Reading 3 Diastolic blood pressure(mmHg)?"
capture label variable glucose "Blood glucose measurement (mmol/L)?"
capture label variable diabetes_meds "What diabetes medication are you on?"
capture label variable hypertension_meds "Are you on hypertension medication?"
capture label variable smoking "Do you currently smoke any tobacco products, such as cigarettes, cigars or pipes?"
capture label variable smoking_past "In the past, did you ever smoke any tobacco products?"
capture label variable core_measurements_complete "Complete?"
capture label variable visit_date_anth "Date of measurement"
capture label variable anthropometry_complete "Complete?"
capture label variable visit_date_hba1c "Date of measurement"
capture label variable hba1c "HbA1c (mmol/mol)?"
capture label variable hba1c_complete "Complete?"
capture label variable visit_date_lm "Date of visit"
capture label variable results_date "Date of lab results"
capture label variable hba1c_copy "HbA1c (mmol/mol)"
capture label variable alt "Alanine aminotransferase (ALT) (U/L)?"
capture label variable ast "Aspartate aminotransferase (AST) (U/L)?"
capture label variable alp "Alkaline phosphatase (ALP) (U/L)?"
capture label variable bilirubin_total "Total bilirubin (µmol/L)?"
capture label variable albumin "Albumin (g/L)?"
capture label variable protein_total "Total protein (g/L)?"
capture label variable ggt "GGT (U/L)?"
capture label variable hb "Haemoglobin (Hb)(g/dL)?"
capture label variable cholesterol_total "Total cholesterol (mmol/L)?"
capture label variable cholesterol_hdl "HDL cholesterol(mmol/L)?"
capture label variable cholesterol_ldl "LDL cholesterol (mmol/L)?"
capture label variable triglyceride "Triglyceride levels(mmol/L)?"
capture label variable sodium "Sodium (Na) (mmol/L)?"
capture label variable potassium "Potassium (K) (mmol/L)?"
capture label variable urea "Urea (mmol/L)?"
capture label variable creatinine "Creatinine (µmol/L)?"
capture label variable egfr "eGFR (mL/min/1.73m2) derived in ASET units"
capture label variable lab_measurements_complete "Complete?"
capture label variable visit_date_em "Date of visit"
capture label variable fibroscan_date "Date of FibroScan assessment"
capture label variable lsm_kpa "Liver stiffness measurement (median) (kilopascals (kPa))?"
capture label variable lsm_iqr "Interquartile range of liver stiffness (kilopascals (kPa))?"
capture label variable cap_dbm "Controlled attenuation parameter (mean) (decibels per metre (dB/m))?"
capture label variable cap_sd "Standard deviation of attenuation (decibels per metre (dB/m))?"
capture label variable eq_mob "Mobility"
capture label variable eq_sc "Self-care"
capture label variable eq_ua "Usual activities"
capture label variable eq_pd "Pain / discomfort"
capture label variable eq_ad "Anxiety / depression"
capture label variable eq_vas "Overall health today, 0 to 100"
capture label variable expanded_measurements_complete "Complete?"
capture label variable visit_date_he "Date completed"
capture label variable he_currency "Currency used for costing"
capture label variable he_currency_oth "If other currency, please specify"
capture label variable he_insulin_supplied "Number of weeks of insulin issued since the previous study visit"
capture label variable he_metformin_supplied "Number of weeks of metformin issued since the previous study visit"
capture label variable he_antihyp_supplied "Number of weeks of antihypertensive issued since the previous study visit"
capture label variable he_notes "Costing notes"
capture label variable health_economics_complete "Complete?"
capture label variable study_id_withdrawal "Participant Study ID"
capture label variable date_withdrawal "Date of withdrawal"
capture label variable phase_withdrawal "Study phase at withdrawal"
capture label variable type_withdrawal "Would you still like community health worker monitoring?"
capture label variable reason_withdrawal "Primary reason for withdrawal"
capture label variable reason_withdrawal_oth "Please specify other withdrawal reason"
capture label variable ae_withdrawal_rpt "Has adverse event already been reported?"
capture label variable dlc_withdrawal "Date of last participant contact"
capture label variable initiated_withdrawal "Who initiated withdrawal?"
capture label variable withdrawal_form_complete "Complete?"
capture label variable study_id_ae "Participant Study ID"
capture label variable date_ae "Date of adverse event"
capture label variable notes_ae "Please describe adverse event"
capture label variable class_ae "Event classification"
capture label variable adverse_event_complete "Complete?"


** -------------------------------------------------------------------------
** Apply preferred variable order where variables exist
**
** This guards against minor future changes in the REDCap project.
** -------------------------------------------------------------------------

local order_vars

foreach v of local preferred_order {
    capture confirm variable `v'
    if !_rc {
        local order_vars `order_vars' `v'
    }
    else {
        di as text "Variable not present in API export: `v'"
    }
}

order `order_vars'


** -------------------------------------------------------------------------
** Final checks
** -------------------------------------------------------------------------

set more off
describe

count
di as result "Final number of rows in full database extract: " r(N)


** -------------------------------------------------------------------------
** Save the full database extract
**
** Two Stata copies are saved:
**     1. A dated archive copy.
**     2. A stable latest copy.
** -------------------------------------------------------------------------

compress

save "`raw_dta_dated'", replace

di as result "Dated full REDCap API extract saved:"
di as result "`raw_dta_dated'"

save "`raw_dta_latest'", replace

di as result "Latest full REDCap API extract saved:"
di as result "`raw_dta_latest'"


** -------------------------------------------------------------------------
** Create a participant-level recruitment and programme-status dataset
**
** The full REDCap extract contains one row for each REDCap event or repeating
** instrument. The monitoring report needs selected values once per person.
**
** This block therefore creates:
**
**     tmr_monitor_participant_status.dta
**
** with one row per record_id.
**
** AGREED RECRUITMENT DEFINITIONS
**
** SCREENED
**     A person is screened when any extracted screening-stage-1 field has a
**     non-missing value. Stage-1 fields are identified by the suffix:
**
**         *_screen_1
**
** ELIGIBLE
**     The source database has no separate simple eligibility indicator.
**     Operationally, interested_screen_2 is completed only for people who
**     have passed second-stage screening. Eligibility is therefore defined
**     as a non-missing interested_screen_2 value.
**
** INTEREST BREAKDOWN
**
**     interested_screen_2 == 1    Interested
**     interested_screen_2 == 2    Not interested
**     interested_screen_2 == 3    Decision pending
**
** WITHDRAWAL
**     A participant is withdrawn only when:
**
**         withdrawal_form_complete == 2
**
** The existing full raw extract remains unchanged.
** -------------------------------------------------------------------------

local status_dta "$cleandir\tmr_monitor_participant_status.dta"

preserve

    ** ---------------------------------------------------------------------
    ** Confirm the specifically named variables required by this block
    ** ---------------------------------------------------------------------

    local required_status_vars ///
        record_id ///
        interested_screen_2 ///
        site ///
        date_withdrawal ///
        withdrawal_form_complete

    foreach v of local required_status_vars {

        capture confirm variable `v'

        if _rc {
            di as error "Required variable for participant status dataset not found: `v'"
            di as error "Check the REDCap API export and field name before continuing."
            restore
            exit 111
        }
    }


    ** ---------------------------------------------------------------------
    ** Identify variables from BOTH screening forms returned by the API
    **
    ** A participant is considered screened if any field has been populated
    ** on either screening form. We therefore include variables ending in:
    **
    **     *_screen_1
    **     *_screen_2
    **
    ** This deliberately does not use participant site. The formal screening
    ** process was undertaken in St Helena, and site is recorded later on the
    ** participant administration form for people progressing to programme.
    ** ---------------------------------------------------------------------

    ds *_screen_1 *_screen_2
    local screening_vars `r(varlist)'

    if "`screening_vars'" == "" {
        di as error "No screening-form variables were found in the API extract."
        di as error "Expected variables ending in _screen_1 or _screen_2."
        restore
        exit 111
    }

    di as result "Screening-form fields identified:"
    di as text "`screening_vars'"


    ** ---------------------------------------------------------------------
    ** SCREENED
    **
    ** The screening forms contain a mixture of variable types. Some fields
    ** are numeric and others are strings.
    **
    ** A participant is considered screened if ANY field on EITHER screening
    ** form contains an entry. This means that a person with information on
    ** Screening 2 but no populated Screening 1 field is still counted as
    ** having been screened in some way.
    **
    ** Because the fields are mixed numeric/string, inspect them one at a
    ** time rather than using egen rownonmiss() across the whole list.
    ** ---------------------------------------------------------------------

    gen byte screened_row = 0

    foreach v of local screening_vars {

        ** Is this screening field stored as a string?
        capture confirm string variable `v'

        if !_rc {

            ** String field:
            ** Treat an empty string as missing. trim() also protects against
            ** a field containing only spaces.
            replace screened_row = 1 ///
                if trim(`v') != ""
        }

        else {

            ** Numeric field:
            ** Stata numeric missing values are represented by . or one of
            ** the extended missing values. missing() handles all of these.
            replace screened_row = 1 ///
                if !missing(`v')
        }
    }

    bysort record_id: egen byte screened = max(screened_row)

    label variable screened ///
        "Any field populated on either screening form"

    drop screened_row


    ** ---------------------------------------------------------------------
    ** ELIGIBLE
    **
    ** A non-missing final interest response is used as operational evidence
    ** that second-stage screening was completed and eligibility confirmed.
    ** ---------------------------------------------------------------------

    gen byte eligible_row = !missing(interested_screen_2)

    bysort record_id: egen byte eligible = max(eligible_row)

    label variable eligible ///
        "Eligible based on non-missing final interest response"

    drop eligible_row


    ** ---------------------------------------------------------------------
    ** INTEREST STATUS
    **
    ** Current REDCap coding:
    **
    **     1 = Yes
    **     2 = No
    **     3 = Maybe
    **
    ** Conflicting values within participant are reported.
    ** ---------------------------------------------------------------------

    bysort record_id: egen interest_min = min(interested_screen_2)
    bysort record_id: egen interest_max = max(interested_screen_2)

    gen byte interest_conflict = ///
        interest_min != interest_max ///
        if !missing(interest_min, interest_max)

    quietly count if interest_conflict == 1

    if r(N) > 0 {
        di as error "WARNING: participants with conflicting final interest values: " r(N)
    }

    gen byte interest_status = interest_max

    label define interest_status_label ///
        1 "Interested" ///
        2 "Not interested" ///
        3 "Decision pending", replace

    label values interest_status interest_status_label

    label variable interest_status ///
        "Interest after second-stage screening"

    drop interest_min interest_max interest_conflict


    ** ---------------------------------------------------------------------
    ** STUDY SITE
    ** ---------------------------------------------------------------------

    bysort record_id: egen site_min = min(site)
    bysort record_id: egen site_max = max(site)

    gen byte site_conflict = ///
        site_min != site_max ///
        if !missing(site_min, site_max)

    quietly count if site_conflict == 1

    if r(N) > 0 {
        di as error "WARNING: participants with conflicting study-site values: " r(N)
    }

    gen byte participant_site = site_max

    label values participant_site site_

    label variable participant_site ///
        "Participant study site"

    drop site_min site_max site_conflict


    ** ---------------------------------------------------------------------
    ** COMPLETED WITHDRAWAL
    **
    ** IMPORTANT:
    ** withdrawal_form_complete is populated only on the REDCap row on which
    ** the withdrawal form is recorded. It is expected to be missing on the
    ** participant's other REDCap rows.
    **
    ** Only code 2 ("Complete") means that the participant has withdrawn.
    ** Missing, 0 and 1 do NOT indicate withdrawal.
    **
    ** We therefore create a row-level flag and then search across ALL rows
    ** for each record_id. If code 2 appears anywhere, that participant is
    ** classified as withdrawn.
    ** ---------------------------------------------------------------------

    capture confirm numeric variable withdrawal_form_complete

    if _rc {
        di as error "withdrawal_form_complete is not numeric after API import."
        di as error "Expected REDCap raw coding with Complete = 2."
        restore
        exit 109
    }

    gen byte withdrawal_complete_row = 0

    replace withdrawal_complete_row = 1 ///
        if withdrawal_form_complete == 2

    bysort record_id: egen byte withdrawn = ///
        max(withdrawal_complete_row)

    label variable withdrawn ///
        "Any REDCap withdrawal form marked Complete"

    drop withdrawal_complete_row


    ** ---------------------------------------------------------------------
    ** Audit the withdrawal classification in the Stata log
    ** ---------------------------------------------------------------------

    di as result "Participants identified as withdrawn:"

    list record_id if withdrawn == 1, ///
        noobs


    ** ---------------------------------------------------------------------
    ** WITHDRAWAL DATE
    ** ---------------------------------------------------------------------

    bysort record_id: egen withdrawal_date_min = min(date_withdrawal)
    bysort record_id: egen withdrawal_date_max = max(date_withdrawal)

    gen byte withdrawal_date_conflict = ///
        withdrawal_date_min != withdrawal_date_max ///
        if !missing(withdrawal_date_min, withdrawal_date_max)

    quietly count if withdrawal_date_conflict == 1

    if r(N) > 0 {
        di as error "WARNING: participants with conflicting withdrawal dates: " r(N)
    }

    gen withdrawal_date = withdrawal_date_max
    format withdrawal_date %dM_d,_CY

    label variable withdrawal_date ///
        "Date on completed withdrawal form"

    drop ///
        withdrawal_date_min ///
        withdrawal_date_max ///
        withdrawal_date_conflict


    ** ---------------------------------------------------------------------
    ** Keep one row per participant
    ** ---------------------------------------------------------------------

    sort record_id
    by record_id: keep if _n == 1

    keep ///
        record_id ///
        screened ///
        eligible ///
        interest_status ///
        participant_site ///
        withdrawn ///
        withdrawal_date

    order ///
        record_id ///
        screened ///
        eligible ///
        interest_status ///
        participant_site ///
        withdrawn ///
        withdrawal_date

    label data ///
        "TMR participant recruitment and programme-status dataset"


    ** ---------------------------------------------------------------------
    ** PARTICIPANT-LEVEL VALIDATION CHECKS
    ** ---------------------------------------------------------------------

    quietly count if eligible == 1 & screened != 1

    if r(N) > 0 {
        di as error "WARNING: eligible participants not flagged as screened: " r(N)
    }

    quietly count if eligible == 1 & missing(interest_status)

    if r(N) > 0 {
        di as error "WARNING: eligible participants with missing interest status: " r(N)
    }

    quietly count if eligible == 0 & !missing(interest_status)

    if r(N) > 0 {
        di as error "WARNING: interest status recorded but eligible indicator is zero: " r(N)
    }

    quietly count if withdrawn == 1 & missing(withdrawal_date)

    if r(N) > 0 {
        di as error "WARNING: completed withdrawal forms with missing withdrawal date: " r(N)
    }

    quietly count if withdrawn == 0 & !missing(withdrawal_date)

    if r(N) > 0 {
        di as error "WARNING: withdrawal dates found without a completed withdrawal form: " r(N)
    }


    ** ---------------------------------------------------------------------
    ** Display a simple status summary in the log
    ** ---------------------------------------------------------------------

    quietly count
    di as result "Participant status records created: " r(N)

    quietly count if screened == 1
    di as result "Screened (any entry on either screening form): " r(N)

    quietly count if screened == 1 & missing(participant_site)
    di as result "Screened with no participant-admin site recorded: " r(N)

    quietly count if eligible == 1
    di as result "Eligible: " r(N)

    quietly count if eligible == 1 & interest_status == 1
    di as result "Eligible and interested: " r(N)

    quietly count if eligible == 1 & interest_status == 2
    di as result "Eligible and not interested: " r(N)

    quietly count if eligible == 1 & interest_status == 3
    di as result "Eligible with decision pending: " r(N)

    quietly count if withdrawn == 1
    di as result "Completed withdrawal forms: " r(N)


    ** ---------------------------------------------------------------------
    ** Save the stable participant-level status dataset
    ** ---------------------------------------------------------------------

    compress

    save "`status_dta'", replace

    di as result "Participant recruitment and status dataset saved:"
    di as result "`status_dta'"

restore


capture log close
