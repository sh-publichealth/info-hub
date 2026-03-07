*******************************************************
* exercise-02-deidentification.do
*
* Companion exercise for Module 1:
* De-identification, pseudonymisation, and anonymisation
*******************************************************

version 19
clear all
set more off
local DATAPATH "C:\quarto\website\info-hub\site\data-skills\module-01\data"

*******************************************************
* 1. Load identifiable teaching dataset
*******************************************************

use "`DATAPATH'\module-01-identifiable-diabetes-data.dta", clear

display " "
display "Loaded identifiable teaching dataset for Exercise 2"
display "Records: " _N
display " "

describe

*******************************************************
* 2. Review obvious identifiers and quasi-identifiers
*******************************************************

display "Potential direct identifiers include:"
display "  patient_name"
display "  hospital_number"
display "  address"
display " "
display "Potential quasi-identifiers include:"
display "  date_of_birth / dob"
display "  sex"
display "  community"
display "  diabetes_type"
display "  clinic_visit_date / visit_date"
display " "

*******************************************************
* 3. Create a de-identified internal analysis dataset
*
* This file is still likely to be personal data because
* people may remain identifiable indirectly.
*******************************************************

preserve

keep patient_id sex community diabetes_type diagnosis_year bmi_category ///
     treatment clinic_visits_last_year age age_group visit_month

rename patient_id study_id
replace study_id = "S" + substr(study_id, 2, .)

label variable study_id "Study identifier for analysis"

save "`DATAPATH'\exercise-02-internal-analysis-file.dta", replace
export delimited using "`DATAPATH'\exercise-02-internal-analysis-file.csv", replace

display "Created de-identified internal analysis file:"
display "  exercise-02-internal-analysis-file.dta"
display "  exercise-02-internal-analysis-file.csv"

restore

*******************************************************
* 4. Show what was removed or transformed
*******************************************************

display " "
display "Changes made for the internal analysis file:"
display "- removed patient_name"
display "- removed hospital_number"
display "- removed address"
display "- replaced original patient_id with study_id"
display "- used age and age_group instead of publishing direct date of birth"
display "- reduced clinic_visit_date to visit_month"
display " "

*******************************************************
* 5. Create a public-facing aggregated output
*******************************************************

preserve

gen n=1 
collapse (count) subtotal=n, by(age_group diabetes_type)
generate suppress = inrange(subtotal, 1, 3)
generate str6 n_public = string(subtotal)
replace n_public = "<4" if suppress == 1

save "`DATAPATH'\exercise-02-public-summary-table.dta", replace
export delimited using "`DATAPATH'\exercise-02-public-summary-table.csv", replace

display " "
display "Public-facing summary table: age group x diabetes type"
list age_group diabetes_type subtotal n_public suppress, noobs sepby(age_group)

restore

*******************************************************
* 6. Community risk demonstration
*******************************************************

preserve

gen n=1 
collapse (count) subtotal=n, by(community diabetes_type age_group)
generate small_cell_risk = inrange(subtotal, 1, 3)

display " "
display "Adding community sharply increases risk in a small population."
list community age_group diabetes_type subtotal if small_cell_risk == 1, noobs sepby(community)

restore

*******************************************************
* 7. Log summary
*******************************************************

capture log close
log using "`DATAPATH'\exercise-02-deidentification.log", replace text

display "Exercise 2 completed successfully."
display "Outputs created:"
display "  exercise-02-internal-analysis-file.dta"
display "  exercise-02-internal-analysis-file.csv"
display "  exercise-02-public-summary-table.dta"
display "  exercise-02-public-summary-table.csv"

log close

display "Done."
