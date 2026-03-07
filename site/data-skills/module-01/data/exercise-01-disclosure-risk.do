*******************************************************
* exercise-01-disclosure-risk.do
*
* Companion exercise for Module 1:
* Responsible Use of Public Health Data
*
* Purpose:
* 1. Load the fictional diabetes dataset
* 2. Produce an unsafe summary table
* 3. Identify small-cell disclosure risk
* 4. Produce safer public-facing tables
*******************************************************

version 19
clear all
set more off
local DATAPATH "C:\quarto\website\info-hub\site\data-skills\module-01\data"

*******************************************************
* 1. Load fictional dataset
*******************************************************

use "`DATAPATH'\module-01-disclosure-diabetes-data.dta", clear

display " "
display "Loaded fictional dataset for Exercise 1"
display "Records: " _N
display " "

*******************************************************
* 2. Quick review of the data
*******************************************************

tabulate age_group
tabulate sex
tabulate diabetes_type
tabulate community

*******************************************************
* 3. UNSAFE TABLE
*
* This is the kind of table an inexperienced analyst
* might produce for a report without thinking carefully
* about confidentiality in a small population.
*******************************************************

display " "
display "=================================================="
display "UNSAFE TABLE: age group x sex x diabetes type"
display "=================================================="
display " "

table (age_group) (sex diabetes_type), ///
    statistic(frequency) ///
    nototals

*******************************************************
* 4. MORE UNSAFE: adding community
*
* Combining community with disease type and sex may make
* people identifiable even if names have been removed.
*******************************************************

display " "
display "=================================================="
display "MORE UNSAFE TABLE: community x sex x diabetes type"
display "=================================================="
display " "

table (community) (sex diabetes_type), ///
    statistic(frequency) ///
    nototals

*******************************************************
* 5. CREATE A CELL-LEVEL RISK CHECK
*
* We collapse to the reporting level and count how many
* people are in each age group x sex x diabetes type cell.
*
* In this teaching example, counts of 1-3 are flagged.
* In practice, many organisations use a threshold below 5
* for public reporting.
*******************************************************

preserve

gen n = 1 
collapse (count) subtotal=n, by(age_group sex diabetes_type)

generate small_cell_risk = inrange(subtotal, 1, 3)

label variable subtotal               "Cell count"
label variable small_cell_risk "1 if count is between 1 and 3"

display " "
display "=================================================="
display "CELL COUNTS FOR AGE GROUP x SEX x DIABETES TYPE"
display "=================================================="
display " "

list age_group sex diabetes_type subtotal small_cell_risk, noobs sepby(age_group)

display " "
display "Cells with potential disclosure risk (count 1-3):"
list age_group sex diabetes_type subtotal if small_cell_risk == 1, noobs sepby(age_group)

save "exercise-01-unsafe-cell-counts.dta", replace
export delimited using "exercise-01-unsafe-cell-counts.csv", replace

restore

*******************************************************
* 6. PRODUCE A SAFER TABLE
*
* One simple safety strategy is to aggregate categories.
* Here we remove the sex split from the public table.
*******************************************************

preserve

gen n = 1 
collapse (count) subtotal=n, by(age_group diabetes_type)

generate suppress = inrange(subtotal, 1, 3)
label variable suppress "1 if count should be suppressed in this example"

generate str6 n_public = string(subtotal)
replace n_public = "<4" if suppress == 1

display " "
display "=================================================="
display "SAFER TABLE: age group x diabetes type"
display "Small counts are masked as <4 in this teaching example"
display "=================================================="
display " "

list age_group diabetes_type subtotal n_public suppress, noobs sepby(age_group)

save "`DATAPATH'\exercise-01-safer-cell-counts.dta", replace
export delimited using "`DATAPATH'\exercise-01-safer-cell-counts.csv", replace

restore

*******************************************************
* 7. EVEN SAFER TABLE
*
* For some audiences, it may be safer still to report
* only total diabetes counts by age group.
*******************************************************

preserve

gen n = 1 
collapse (count) subtotal=n, by(age_group)

generate suppress = inrange(subtotal, 1, 3)
generate str6 n_public = string(subtotal)
replace n_public = "<4" if suppress == 1

display " "
display "=================================================="
display "EVEN SAFER TABLE: total patients by age group"
display "=================================================="
display " "

list age_group subtotal n_public suppress, noobs

save "`DATAPATH'\exercise-01-safest-cell-counts.dta", replace
export delimited using "`DATAPATH'\exercise-01-safest-cell-counts.csv", replace

restore

*******************************************************
* 8. OPTIONAL: COMMUNITY RISK DEMONSTRATION
*******************************************************

preserve

gen n = 1 
collapse (count) subtotal=n, by(community diabetes_type)

generate small_cell_risk = inrange(subtotal, 1, 3)

display " "
display "=================================================="
display "COMMUNITY x DIABETES TYPE CELL COUNTS"
display "=================================================="
display " "

list community diabetes_type subtotal small_cell_risk, noobs sepby(community)

display " "
display "Community-level cells with potential disclosure risk:"
list community diabetes_type subtotal if small_cell_risk == 1, noobs sepby(community)

save "`DATAPATH'\exercise-01-community-risk-counts.dta", replace
export delimited using "`DATAPATH'\exercise-01-community-risk-counts.csv", replace

restore

*******************************************************
* 9. SHORT EXERCISE PROMPTS FOR THE TRAINEE
*******************************************************

display " "
display "=================================================="
display "REFLECTION QUESTIONS"
display "=================================================="
display "1. Which table would be unsafe for public release?"
display "2. Which cells create the main disclosure risks?"
display "3. What information is lost when categories are aggregated?"
display "4. Why might community be especially risky in a small population?"
display "5. Which version would be suitable for an internal report only?"
display "6. Which version would be safer for a public report?"
display " "

*******************************************************
* 10. Save a log-friendly summary file
*******************************************************

capture log close
log using "exercise-01-disclosure-risk.log", replace text

display "Exercise 1 disclosure-risk exercise completed successfully."
display "Outputs created:"
display "  exercise-01-unsafe-cell-counts.dta"
display "  exercise-01-unsafe-cell-counts.csv"
display "  exercise-01-safer-cell-counts.dta"
display "  exercise-01-safer-cell-counts.csv"
display "  exercise-01-safest-cell-counts.dta"
display "  exercise-01-safest-cell-counts.csv"
display "  exercise-01-community-risk-counts.dta"
display "  exercise-01-community-risk-counts.csv"

log close

display " "
display "Done."
