*******************************************************
* create-module-01-identifiable-dataset.do
* Creates a fictional identifiable dataset for Exercise 2:
* de-identification, pseudonymisation, and anonymisation.
*******************************************************

version 19
clear all
set more off

*******************************************************
* 1. Create fictional records
*******************************************************

input ///
str4 patient_id str20 patient_name str8 hospital_number str10 date_of_birth ///
str1 sex str18 address str12 community str5 diabetes_type diagnosis_year ///
str12 bmi_category str8 treatment clinic_visits_last_year str10 clinic_visit_date
"P001" "Maya George"      "H100001" "1958-04-12" "F" "1 Wharf Lane"     "Jamestown" "Type2" 2012 "Obese"      "Tablets" 4 "2026-01-16"
"P002" "Jon Peters"       "H100002" "1954-09-30" "M" "2 Market Street"  "Jamestown" "Type2" 2010 "Overweight" "Tablets" 3 "2026-02-03"
"P003" "Elena Leo"        "H100003" "1967-02-18" "F" "3 Hill Road"      "HalfTree"  "Type2" 2018 "Obese"      "Mixed"   5 "2026-01-28"
"P004" "Daniel Henry"     "H100004" "1998-07-07" "M" "4 Bay View"       "SandyBay"  "Type1" 2015 "Normal"     "Insulin" 6 "2026-02-11"
"P005" "Tara Joshua"      "H100005" "1991-01-24" "F" "5 Church Lane"    "Levelwood" "Type1" 2020 "Normal"     "Insulin" 4 "2026-01-09"
"P006" "Anita Lewis"      "H100006" "1963-11-02" "F" "6 Main Road"      "Jamestown" "Type2" 2011 "Obese"      "Mixed"   5 "2026-03-01"
"P007" "Paul Thomas"      "H100007" "1972-06-17" "M" "7 Upper Road"     "HalfTree"  "Type2" 2016 "Overweight" "Tablets" 3 "2026-02-14"
"P008" "Clara Yon"        "H100008" "1979-03-29" "F" "8 Harbour View"   "Jamestown" "Type2" 2019 "Obese"      "Tablets" 2 "2026-02-19"
"P009" "Marcus Bennett"   "H100009" "1965-10-08" "M" "9 Long Lane"      "Longwood"  "Type2" 2014 "Obese"      "Mixed"   6 "2026-01-21"
"P010" "Rita Williams"    "H100010" "1951-12-05" "F" "10 Green Path"    "Jamestown" "Type2" 2008 "Overweight" "Tablets" 4 "2026-02-26"
"P011" "David Duncan"     "H100011" "1983-04-19" "M" "11 Valley Road"   "HalfTree"  "Type2" 2017 "Overweight" "Diet"    2 "2026-01-12"
"P012" "Joanne Joseph"    "H100012" "1974-08-10" "F" "12 School Lane"   "HalfTree"  "Type2" 2013 "Obese"      "Tablets" 3 "2026-02-10"
"P013" "Malcolm Grant"    "H100013" "1960-05-27" "M" "13 Cliff Road"    "Jamestown" "Type2" 2009 "Obese"      "Mixed"   5 "2026-03-03"
"P014" "Sarah Sim"        "H100014" "1987-09-14" "F" "14 Farm Track"    "Levelwood" "Type2" 2021 "Overweight" "Diet"    2 "2026-01-31"
"P015" "Liam O'Neil"      "H100015" "1996-02-02" "M" "15 Bay Road"      "SandyBay"  "Type2" 2022 "Obese"      "Tablets" 2 "2026-03-06"
"P016" "Grace Peters"     "H100016" "1968-07-23" "F" "16 Long Tree"     "Longwood"  "Type2" 2015 "Obese"      "Mixed"   4 "2026-02-24"
"P017" "Roy George"       "H100017" "1955-03-11" "M" "17 Upper Hill"    "Jamestown" "Type2" 2011 "Overweight" "Tablets" 3 "2026-02-07"
"P018" "Vera Francis"     "H100018" "1961-01-15" "F" "18 West Lane"     "HalfTree"  "Type2" 2010 "Obese"      "Mixed"   5 "2026-01-18"
"P019" "Neil Thomas"      "H100019" "1974-10-21" "M" "19 Castle View"   "Jamestown" "Type2" 2018 "Overweight" "Tablets" 3 "2026-02-12"
"P020" "Mina Lawrence"    "H100020" "1979-06-01" "F" "20 South Road"    "Longwood"  "Type2" 2019 "Obese"      "Diet"    2 "2026-01-27"
"P021" "Peter George"     "H100021" "1963-08-26" "M" "21 Pier Road"     "Jamestown" "Type2" 2012 "Obese"      "Mixed"   4 "2026-02-16"
"P022" "Rose Fowler"      "H100022" "1952-11-19" "F" "22 Palm Cottages" "Jamestown" "Type2" 2007 "Overweight" "Tablets" 3 "2026-03-04"
"P023" "Ken Richards"     "H100023" "1968-12-12" "M" "23 Ridge Lane"    "HalfTree"  "Type2" 2016 "Obese"      "Tablets" 4 "2026-02-09"
"P024" "Linda Beadon"     "H100024" "1959-05-05" "F" "24 East View"     "Longwood"  "Type2" 2013 "Obese"      "Mixed"   5 "2026-01-15"
"P025" "Aaron Williams"   "H100025" "1976-04-07" "M" "25 School Road"   "Levelwood" "Type2" 2020 "Overweight" "Diet"    2 "2026-02-20"
"P026" "Paula George"     "H100026" "1971-09-01" "F" "26 Main Street"   "Jamestown" "Type2" 2014 "Obese"      "Tablets" 3 "2026-01-22"
"P027" "Simon Yon"        "H100027" "1953-07-04" "M" "27 North Road"    "Jamestown" "Type2" 2006 "Overweight" "Mixed"   5 "2026-02-28"
"P028" "Faith O'Bey"      "H100028" "1964-03-16" "F" "28 Valley Track"  "HalfTree"  "Type2" 2011 "Obese"      "Tablets" 4 "2026-03-02"
"P029" "Leon Henry"       "H100029" "1982-05-14" "M" "29 Hillview"      "Longwood"  "Type2" 2017 "Obese"      "Tablets" 3 "2026-01-29"
"P030" "Janice Leo"       "H100030" "1957-02-27" "F" "30 Garden Path"   "Jamestown" "Type2" 2009 "Overweight" "Mixed"   4 "2026-02-25"
"P031" "Keira Thomas"     "H100031" "1997-10-09" "F" "31 Bay Cottages"  "SandyBay"  "Type1" 2018 "Normal"     "Insulin" 5 "2026-02-08"
"P032" "Owen Peters"      "H100032" "1989-01-03" "M" "32 Ridge Road"    "Longwood"  "Type1" 2010 "Normal"     "Insulin" 4 "2026-01-14"
"P033" "Nia George"       "H100033" "2001-06-22" "F" "33 Hill Top"      "BlueHill"  "Type1" 2022 "Normal"     "Insulin" 6 "2026-02-18"
"P034" "Caleb Joshua"     "H100034" "1984-09-06" "M" "34 Wharf Lane"    "Jamestown" "Type1" 2005 "Normal"     "Insulin" 5 "2026-03-05"
"P035" "Martha Sim"       "H100035" "1960-01-30" "F" "35 Church View"   "Levelwood" "Type1" 1998 "Normal"     "Insulin" 4 "2026-01-20"
"P036" "Eli Duncan"       "H100036" "1993-12-13" "M" "36 West Path"     "BlueHill"  "Type2" 2021 "Obese"      "Tablets" 2 "2026-02-21"
"P037" "Hannah Bennett"   "H100037" "1983-07-19" "F" "37 Main Road"     "Jamestown" "Type2" 2018 "Overweight" "Diet"    2 "2026-02-15"
"P038" "Mark Francis"     "H100038" "1962-10-01" "M" "38 Farm Lane"     "HalfTree"  "Type2" 2012 "Obese"      "Mixed"   4 "2026-01-25"
"P039" "Olive Richards"   "H100039" "1973-11-24" "F" "39 Harbour Lane"  "Longwood"  "Type2" 2016 "Obese"      "Tablets" 3 "2026-02-23"
"P040" "Noah Lawrence"    "H100040" "1948-08-18" "M" "40 Upper Street"  "Jamestown" "Type2" 2004 "Overweight" "Mixed"   5 "2026-03-07"
end

*******************************************************
* 2. Convert dates and create derived variables
*******************************************************

generate dob = daily(date_of_birth, "YMD")
format dob %td

generate visit_date = daily(clinic_visit_date, "YMD")
format visit_date %td

generate age = floor((mdy(3, 7, 2026) - dob) / 365.25)
generate age_group = ""
replace age_group = "<40"   if age < 40
replace age_group = "40-59" if inrange(age, 40, 59)
replace age_group = "60+"   if age >= 60

generate visit_month = mofd(visit_date)
format visit_month %tm

label variable patient_id              "Original fictional patient identifier"
label variable patient_name            "Fictional patient name"
label variable hospital_number         "Fictional hospital number"
label variable date_of_birth           "Date of birth as text"
label variable dob                     "Date of birth"
label variable sex                     "Sex"
label variable address                 "Address"
label variable community               "Community of residence"
label variable diabetes_type           "Diabetes type"
label variable diagnosis_year          "Year of diagnosis"
label variable bmi_category            "BMI category"
label variable treatment               "Current treatment"
label variable clinic_visits_last_year "Clinic visits in last year"
label variable clinic_visit_date       "Clinic visit date as text"
label variable visit_date              "Clinic visit date"
label variable age                     "Age in years"
label variable age_group               "Age group"
label variable visit_month             "Month of clinic visit"

*******************************************************
* 3. Save dataset
*******************************************************

local DATAPATH "C:\quarto\website\info-hub\site\data-skills\module-01\data"
save "`DATAPATH'\module-01-identifiable-diabetes-data.dta", replace
export delimited using "`DATAPATH'\module-01-identifiable-diabetes-data.csv", replace

display "Identifiable teaching dataset created."
display "Files saved:"
display "  module-01-identifiable-diabetes-data.dta"
display "  module-01-identifiable-diabetes-data.csv"
