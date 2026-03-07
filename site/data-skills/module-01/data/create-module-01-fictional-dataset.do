*******************************************************
* create-module-01-fictional-dataset.do
* Creates a fictional diabetes clinic dataset for
* teaching disclosure risk in a small population.
*******************************************************

version 19
clear all
set more off

*******************************************************
* 1. Create fictional records
*******************************************************

input ///
str4 patient_id str1 sex age str5 diabetes_type diagnosis_year ///
str12 bmi_category str8 treatment clinic_visits_last_year str12 community
"P001" "F" 68 "Type2" 2012 "Obese"       "Tablets" 4 "Jamestown"
"P002" "M" 72 "Type2" 2010 "Overweight"  "Tablets" 3 "Jamestown"
"P003" "F" 59 "Type2" 2018 "Obese"       "Mixed"   5 "HalfTree"
"P004" "M" 27 "Type1" 2015 "Normal"      "Insulin" 6 "SandyBay"
"P005" "F" 34 "Type1" 2020 "Normal"      "Insulin" 4 "Levelwood"
"P006" "F" 63 "Type2" 2011 "Obese"       "Mixed"   5 "Jamestown"
"P007" "M" 54 "Type2" 2016 "Overweight"  "Tablets" 3 "HalfTree"
"P008" "F" 47 "Type2" 2019 "Obese"       "Tablets" 2 "Jamestown"
"P009" "M" 61 "Type2" 2014 "Obese"       "Mixed"   6 "Longwood"
"P010" "F" 75 "Type2" 2008 "Overweight"  "Tablets" 4 "Jamestown"
"P011" "M" 43 "Type2" 2017 "Overweight"  "Diet"    2 "HalfTree"
"P012" "F" 52 "Type2" 2013 "Obese"       "Tablets" 3 "HalfTree"
"P013" "M" 66 "Type2" 2009 "Obese"       "Mixed"   5 "Jamestown"
"P014" "F" 38 "Type2" 2021 "Overweight"  "Diet"    2 "Levelwood"
"P015" "M" 29 "Type2" 2022 "Obese"       "Tablets" 2 "SandyBay"
"P016" "F" 57 "Type2" 2015 "Obese"       "Mixed"   4 "Longwood"
"P017" "M" 70 "Type2" 2011 "Overweight"  "Tablets" 3 "Jamestown"
"P018" "F" 64 "Type2" 2010 "Obese"       "Mixed"   5 "HalfTree"
"P019" "M" 51 "Type2" 2018 "Overweight"  "Tablets" 3 "Jamestown"
"P020" "F" 46 "Type2" 2019 "Obese"       "Diet"    2 "Longwood"
"P021" "M" 62 "Type2" 2012 "Obese"       "Mixed"   4 "Jamestown"
"P022" "F" 71 "Type2" 2007 "Overweight"  "Tablets" 3 "Jamestown"
"P023" "M" 58 "Type2" 2016 "Obese"       "Tablets" 4 "HalfTree"
"P024" "F" 67 "Type2" 2013 "Obese"       "Mixed"   5 "Longwood"
"P025" "M" 49 "Type2" 2020 "Overweight"  "Diet"    2 "Levelwood"
"P026" "F" 55 "Type2" 2014 "Obese"       "Tablets" 3 "Jamestown"
"P027" "M" 73 "Type2" 2006 "Overweight"  "Mixed"   5 "Jamestown"
"P028" "F" 60 "Type2" 2011 "Obese"       "Tablets" 4 "HalfTree"
"P029" "M" 44 "Type2" 2017 "Obese"       "Tablets" 3 "Longwood"
"P030" "F" 69 "Type2" 2009 "Overweight"  "Mixed"   4 "Jamestown"
"P031" "F" 28 "Type1" 2018 "Normal"      "Insulin" 5 "SandyBay"
"P032" "M" 36 "Type1" 2010 "Normal"      "Insulin" 4 "Longwood"
"P033" "F" 24 "Type1" 2022 "Normal"      "Insulin" 6 "BlueHill"
"P034" "M" 41 "Type1" 2005 "Normal"      "Insulin" 5 "Jamestown"
"P035" "F" 65 "Type1" 1998 "Normal"      "Insulin" 4 "Levelwood"
"P036" "M" 33 "Type2" 2021 "Obese"       "Tablets" 2 "BlueHill"
"P037" "F" 42 "Type2" 2018 "Overweight"  "Diet"    2 "Jamestown"
"P038" "M" 64 "Type2" 2012 "Obese"       "Mixed"   4 "HalfTree"
"P039" "F" 53 "Type2" 2016 "Obese"       "Tablets" 3 "Longwood"
"P040" "M" 78 "Type2" 2004 "Overweight"  "Mixed"   5 "Jamestown"
end

*******************************************************
* 2. Create derived variables
*******************************************************

generate age_group = ""
replace age_group = "<40"   if age < 40
replace age_group = "40-59" if inrange(age, 40, 59)
replace age_group = "60+"   if age >= 60

generate duration_diabetes = 2026 - diagnosis_year

generate disclosure_flag = 0
replace disclosure_flag = 1 if community == "BlueHill"
replace disclosure_flag = 1 if diabetes_type == "Type1" & age < 30
replace disclosure_flag = 1 if diabetes_type == "Type1" & community == "SandyBay"

label variable patient_id              "Fictional patient identifier"
label variable sex                     "Sex"
label variable age                     "Age in years"
label variable age_group               "Age group"
label variable diabetes_type           "Diabetes type"
label variable diagnosis_year          "Year of diagnosis"
label variable duration_diabetes       "Years since diagnosis"
label variable bmi_category            "BMI category"
label variable treatment               "Current treatment"
label variable clinic_visits_last_year "Clinic visits in last year"
label variable community               "Community of residence"
label variable disclosure_flag         "Potentially high disclosure-risk profile"

*******************************************************
* 3. Basic checks
*******************************************************

display " "
display "Dataset created successfully"
display "Number of records: " _N
display " "

tabulate sex
tabulate diabetes_type
tabulate age_group
tabulate age_group diabetes_type, row
table (age_group sex) (diabetes_type), ///
    statistic(frequency) statistic(percent, across(diabetes_type))


display " "
display "Potential disclosure-risk records:"
list patient_id sex age age_group diabetes_type community if disclosure_flag == 1, noobs sepby(community)

*******************************************************
* 4. Save dataset
*******************************************************
local DATAPATH "C:\quarto\website\info-hub\site\data-skills\module-01\data"
save "`DATAPATH'\module-01-disclosure-diabetes-data.dta", replace
export delimited using "`DATAPATH'\module-01-disclosure-diabetes-data.csv", replace

display " "
display "Files saved:"
display "  module-01-fictional-diabetes-data.dta"
display "  module-01-fictional-diabetes-data.csv"
display " "
display "Done."
