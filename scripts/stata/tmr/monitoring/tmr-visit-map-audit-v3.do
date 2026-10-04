** Live visit-map preflight v3; automatically extends confirmed repeat rules. Reads real raw data; exports event metadata only.
** args: DATA_ROOT VISIT_MAP. Defaults are the explicit SHG locations.
version 19
clear all
args data_root visit_map
set more off
if `"`data_root'"' == "" local data_root "C:/yoshimi-hot/output/analyse-sth/sh007-total-meal-replacement/stata"
if `"`visit_map'"' == "" local visit_map "C:/yoshimi-hot/output/analyse-sth/sh003-diabetes-registry/info-hub/scripts/stata/tmr/monitoring/config/tmr-visit-map.csv"
confirm file "`data_root'/data_raw/tmr_full_redcap_api_extract_latest.dta"
use "`data_root'/data_raw/tmr_full_redcap_api_extract_latest.dta", clear
confirm variable redcap_event_name
capture confirm variable redcap_repeat_instance
if _rc gen long redcap_repeat_instance = .
capture confirm numeric variable redcap_repeat_instance
if _rc destring redcap_repeat_instance, replace
gen long repeat_instance = redcap_repeat_instance
replace repeat_instance = 0 if missing(repeat_instance)
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
if _N == 0 {
    di as error "No measurement events were found in the real raw extract."
    exit 2000
}

** Keep ALL existing map rows, including visits absent from this extract.
gen byte _observed = 1
capture confirm file `"`visit_map'"'
local map_exists = !_rc
if `map_exists' {
    tempfile existing_map
    preserve
        import delimited using `"`visit_map'"', clear varnames(1) stringcols(_all)
        foreach v in redcap_event_name repeat_instance planned_visit display_order visit_label {
            confirm variable `v'
        }
        replace redcap_event_name = strtrim(redcap_event_name)
        foreach v in repeat_instance planned_visit {
            destring `v', replace
        }
        gen double _read_order = real(display_order)
        assert !missing(_read_order) if strtrim(display_order) != ""
        drop display_order
        rename _read_order display_order
        replace repeat_instance = 0 if missing(repeat_instance)
        isid redcap_event_name repeat_instance
        keep redcap_event_name repeat_instance planned_visit display_order visit_label
        save `existing_map'
    restore
    merge 1:1 redcap_event_name repeat_instance using `existing_map', gen(_map_merge)
}
else {
    gen byte planned_visit = .
    gen double display_order = .
    gen str100 visit_label = ""
    gen byte _map_merge = 1
}
** Avoid float rounding of fractional optional-visit display positions.
recast double display_order
recast str100 visit_label
gen byte _rule_visit = .
gen double _rule_order = .
gen str100 _rule_label = ""
replace _rule_visit = 1 if redcap_event_name == "baseline_arm_2" & repeat_instance == 0
replace _rule_label = "Baseline" if _rule_visit == 1
forvalues j = 1/6 {
    if `j' != 5 {
        replace _rule_visit = `j' + 1 if redcap_event_name == "tmr_visit_`j'_arm_2" & repeat_instance == 0
        replace _rule_label = "TMR visit `j'" if redcap_event_name == "tmr_visit_`j'_arm_2" & repeat_instance == 0
    }
}
forvalues j = 1/3 {
    replace _rule_visit = `j' + 7 if redcap_event_name == "food_visit_`j'_arm_2" & repeat_instance == 0
    replace _rule_label = "Food visit `j'" if redcap_event_name == "food_visit_`j'_arm_2" & repeat_instance == 0
}
** Confirmed by programme lead, 1 October 2026:
** instance 1 is scheduled; later instances are extra visits at these TWO events.
replace _rule_visit = 6 if redcap_event_name == "tmr_visit_5_arm_2" & repeat_instance == 1
replace _rule_label = "TMR visit 5" if redcap_event_name == "tmr_visit_5_arm_2" & repeat_instance == 1
replace _rule_visit = 11 if redcap_event_name == "food_visit_4_arm_2" & repeat_instance == 1
replace _rule_label = "Food visit 4" if redcap_event_name == "food_visit_4_arm_2" & repeat_instance == 1
replace _rule_order = _rule_visit if _rule_visit > 0 & !missing(_rule_visit)
foreach event in tmr_visit_5_arm_2 food_visit_4_arm_2 {
    local anchor = cond("`event'" == "tmr_visit_5_arm_2",6,11)
    local phase = cond("`event'" == "tmr_visit_5_arm_2","TMR","Food")
    replace _rule_visit = 0 if redcap_event_name == "`event'" & repeat_instance > 1 & !missing(repeat_instance)
    ** Increasing order within (anchor, anchor+1), for any positive repeat count.
    replace _rule_order = `anchor' + (repeat_instance - 1)/repeat_instance if redcap_event_name == "`event'" & repeat_instance > 1 & !missing(repeat_instance)
    replace _rule_label = "Extra `phase' visit " + strtrim(string(repeat_instance - 1,"%12.0f")) if redcap_event_name == "`event'" & repeat_instance > 1 & !missing(repeat_instance)
}
** Never silently rewrite an existing mapping that contradicts these rules.
quietly count if !missing(_rule_visit,planned_visit) & (planned_visit != _rule_visit | (!missing(display_order) & abs(display_order - _rule_order) > 1e-10))
if r(N) > 0 {
    di as error "Existing visit map conflicts with the confirmed scheduling rules."
    list redcap_event_name repeat_instance planned_visit display_order _rule_visit _rule_order if !missing(_rule_visit,planned_visit) & (planned_visit != _rule_visit | (!missing(display_order) & abs(display_order - _rule_order) > 1e-10)), noobs
    di as error "Review the map; no map update or PDF has been produced."
    exit 459
}
gen byte _updated = _map_merge == 1 | missing(planned_visit,display_order) | strtrim(visit_label) == ""
replace planned_visit = _rule_visit if missing(planned_visit) & !missing(_rule_visit)
replace display_order = _rule_order if missing(display_order) & !missing(_rule_order)
replace visit_label = _rule_label if strtrim(visit_label) == "" & _rule_label != ""
quietly count if _observed == 1 & (missing(planned_visit,display_order) | strtrim(visit_label) == "")
local n_unmapped = r(N)
local draft_date = subinstr(strtrim("`c(current_date)'")," ","_",.)
local draft_time = subinstr("`c(current_time)'",":","",.)
if `n_unmapped' > 0 {
    capture mkdir "`data_root'/config"
    local draft_csv "`data_root'/config/tmr-visit-map-draft_`draft_date'_`draft_time'.csv"
    preserve
        keep if _observed == 1
        keep redcap_event_name repeat_instance planned_visit display_order visit_label
        order redcap_event_name repeat_instance planned_visit display_order visit_label
        export delimited using `"`draft_csv'"'
    restore
    di as error "Unrecognised measurement event/instance combinations: `n_unmapped'"
    di as result "Event-only draft written to: `draft_csv'"
    di as error "Review these new events. No map update or PDF has been produced."
    exit 459
}
** Validate the complete union before changing the on-disk map.
assert repeat_instance >= 0 & repeat_instance == floor(repeat_instance) & !missing(repeat_instance)
assert inrange(planned_visit,0,20) & planned_visit == floor(planned_visit)
assert !missing(display_order) & strtrim(visit_label) != ""
assert display_order == planned_visit if planned_visit > 0
assert !inlist(display_order,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20) if planned_visit == 0
assert display_order > 1 & display_order < 21 if planned_visit == 0
isid redcap_event_name repeat_instance
quietly count if _updated == 1
local n_updated = r(N)
if `n_updated' > 0 | `map_exists' == 0 {
    ** A failed backup stops the run before the existing map can be overwritten.
    if `map_exists' {
        local backup_csv `"`visit_map'.backup_`draft_date'_`draft_time'.csv"'
        copy `"`visit_map'"' `"`backup_csv'"'
        di as result "Previous map backed up to: `backup_csv'"
    }
    keep redcap_event_name repeat_instance planned_visit display_order visit_label
    order redcap_event_name repeat_instance planned_visit display_order visit_label
    sort display_order redcap_event_name repeat_instance
    format display_order %21.16g
    export delimited using `"`visit_map'"', replace
    di as result "Visit map automatically updated: `n_updated' rows added/completed."
}
else di as result "Visit map unchanged; all real measurement events are covered."
