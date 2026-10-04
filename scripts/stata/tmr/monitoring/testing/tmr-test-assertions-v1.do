** Assertions against the actual Stata-prepared synthetic data.
version 19
args test_root
use "`test_root'/data_clean/tmr_full_analysis_dataset_v2_latest.dta", clear
assert prog_visit_num == 7 if redcap_event_name == "tmr_visit_6_arm_2"
assert missing(prog_visit_num) if planned_visit == 0
assert prog_visit_num == 4 if record_id == "306-90003" & redcap_event_name == "tmr_visit_3_arm_2"
assert missing(baseline_hba1c) if record_id == "305-90004"
assert missing(change_hba1c_abs) if record_id == "305-90004"
assert meds_count_category == 0 if inlist(diabetes_meds,5,6)
assert meds_count_category == 1 if inlist(diabetes_meds,1,2)
assert meds_count_category == 3 if diabetes_meds == 4
quietly count if record_id == "305-90017" & planned_visit == 0
assert r(N) == 5
keep if has_pmeas == 1 & !missing(prog_visit_num)
collapse (max) meds_count_category baseline_meds_category hba1c baseline_prog_date, by(record_id prog_visit_num)
isid record_id prog_visit_num
quietly count if prog_visit_num == 7 & !missing(meds_count_category)
assert r(N) == 4
quietly count if prog_visit_num == 7 & meds_count_category == 0
assert r(N) == 2
quietly count if prog_visit_num == 7 & meds_count_category == 1
assert r(N) == 1
quietly count if prog_visit_num == 7 & meds_count_category == 2
assert r(N) == 0
quietly count if prog_visit_num == 7 & meds_count_category == 3
assert r(N) == 1
quietly count if prog_visit_num == 7 & !missing(meds_count_category,baseline_meds_category)
assert r(N) == 3
quietly count if prog_visit_num == 7 & !missing(meds_count_category,baseline_meds_category) & meds_count_category < baseline_meds_category
assert r(N) == 2
quietly count if prog_visit_num == 7 & !missing(meds_count_category,baseline_meds_category) & meds_count_category == baseline_meds_category
assert r(N) == 0
quietly count if prog_visit_num == 7 & !missing(meds_count_category,baseline_meds_category) & meds_count_category > baseline_meds_category
assert r(N) == 1
quietly count if prog_visit_num == 1 & !missing(baseline_prog_date)
assert r(N) == 5
di as result "Synthetic visit and medication assertions PASSED."
