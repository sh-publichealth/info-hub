** Create a draft visit map from the existing raw export. No API calls.
** do ".../tmr-visit-map-audit-v1.do" "DATA_ROOT" "DRAFT_CSV"
version 19
clear all
args data_root draft_csv
set more off
if `"`data_root'"' == "" local data_root "C:/yoshimi-hot/output/analyse-sth/sh007-total-meal-replacement/stata"
if `"`draft_csv'"' == "" local draft_csv "`data_root'/tmr-visit-map-draft.csv"
use "`data_root'/data_raw/tmr_full_redcap_api_extract_latest.dta", clear
confirm variable redcap_event_name
capture confirm variable redcap_repeat_instance
if _rc gen long redcap_repeat_instance = .
capture confirm numeric variable redcap_repeat_instance
if _rc destring redcap_repeat_instance, replace
gen long repeat_instance = redcap_repeat_instance
replace repeat_instance = 0 if missing(repeat_instance)
** Retain events with any non-missing measurement date or outcome. Form
** completion flags are also included, matching the preparation's broad mask.
gen byte measurement_row = 0
local measurement_vars ///
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
foreach v of local measurement_vars {
    capture confirm variable `v'
    if !_rc replace measurement_row = 1 if !missing(`v')
}
keep if measurement_row == 1
keep redcap_event_name repeat_instance
duplicates drop
sort redcap_event_name repeat_instance
gen byte planned_visit = .
gen double display_order = .
gen str100 visit_label = ""
replace planned_visit = 1 if redcap_event_name == "baseline_arm_2" & repeat_instance == 0
replace display_order = 1 if planned_visit == 1
replace visit_label = "Baseline" if planned_visit == 1
order redcap_event_name repeat_instance planned_visit display_order visit_label
** Never overwrite an event map. The draft is a distinct file.
export delimited using `"`draft_csv'"'
di as result "Draft event/instance map: `draft_csv'"
di as result "Fill planned_visit/display_order/visit_label using REDCap event definitions."
di as result "See README-tmr-monitoring-v4.md for the scheduled visit codes."
