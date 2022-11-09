***********************************************************************************************************************

** Human Development Report Office (HDRO), United Nations Development Programme
** Multidimensional Poverty Index 2022 release

** Methodology developed in partnership with the Oxford Poverty and Human Development Initiative, University of Oxford

************************************************************************************************************************


clear all 
set more off
set maxvar 10000


*** Working Folder Path ***	  
global path_in "C:\Users\cecilia.calderon\Documents\HDRO_MCC\MPI\MPI 2.0\Viet Nam 2020-21_MICS\" 
global path_out "C:\Users\cecilia.calderon\Documents\HDRO_MCC\MPI\MPI 2.0\Viet Nam 2020-21_MICS\"
global path_ado "C:"

	
********************************************************************************
*** VIETNAM MICS 2020/2021 ***
********************************************************************************


********************************************************************************
*** Step 1: Data preparation 
*** Selecting main variables from CH, WM, HH & MN recode & merging with HL recode 
********************************************************************************


********************************************************************************
*** Step 1.1 CH - CHILDREN's RECODE (under 5)
********************************************************************************	

	//No anthropometric data. 
	

********************************************************************************
*** Step 1.2  BH - BIRTH RECODE 
*** (All females 15-49 years who ever gave birth)  
********************************************************************************


use "$path_in/bh.dta", clear


rename _all, lower	

		
*** Generate individual unique key variable required for data merging using:
	*** hh1=cluster number; 
	*** hh2=household number; 
	*** wm4=women's line number.   
gen double ind_id = hh1*100000 + hh2*100 + ln 
format ind_id %20.0g
label var ind_id "Individual ID"

duplicates report ind_id bhln

d bh4c bh9c bh5	
gen date_death = bh4c + bh9c	
	//Date of death = date of birth (bh4c) + age at death (bh9c)	
gen mdead_survey = wdoi-date_death	
	//Months dead from survey = Date of interview (wdoi) - date of death	
replace mdead_survey = . if (bh9c==0 | bh9c==.) & bh5==1	
	/*Replace children who are alive as '.' to distinguish them from children 
	who died at 0 months */ 
gen ydead_survey = mdead_survey/12
	//Years dead from survey
	
	
gen age_death = bh9c if bh5==2
label var age_death "Age at death in months"	
tab age_death, miss			
	
	
codebook bh5, tab (10)	
gen child_died = 1 if bh5==2
replace child_died = 0 if bh5==1
replace child_died = . if bh5==.
label define lab_died 0"child is alive" 1"child has died"
label values child_died lab_died
tab bh5 child_died, miss
	
	
bysort ind_id: egen tot_child_died = sum(child_died) 
	//For each woman, sum the number of children who died
		
	
	//Identify child under 18 mortality in the last 5 years
replace child_died=0 if age_death>=216 & age_death<.
label values child_died lab_died
tab child_died, miss	
	
bysort ind_id: egen tot_child_died_5y=sum(child_died) if ydead_survey<=5
	/*Total number of children under 18 who died in the past 5 years 
	prior to the interview date */	
	
replace tot_child_died_5y=0 if tot_child_died_5y==. & tot_child_died>=0 & tot_child_died<.
	/*All children who are alive or who died longer than 5 years from the 
	interview date are replaced as '0'*/
	
replace tot_child_died_5y=. if child_died==1 & ydead_survey==.
	//Replace as '.' if there is no information on when the child died  

tab tot_child_died tot_child_died_5y, miss

bysort ind_id: egen child_died_per_wom_5y = max(tot_child_died_5y)
lab var child_died_per_wom_5y "Total child under 18 death for each women in the last 5 years (birth recode)"
	

	//Keep one observation per women
bysort ind_id: gen id=1 if _n==1
keep if id==1
drop id
duplicates report ind_id 


gen women_BH = 1 
	//Identification variable for observations in BH recode

	
	//Retain relevant variables
keep ind_id women_BH child_died_per_wom_5y 
order ind_id women_BH child_died_per_wom_5y
sort ind_id
save "$path_out/VNM21_BH.dta", replace	


********************************************************************************
*** Step 1.3  WM - WOMEN's RECODE  
*** (All eligible females 15-49 years in the household)
********************************************************************************

use "$path_in/wm.dta", clear 

	
rename _all, lower	

	
*** Generate individual unique key variable required for data merging
*** hh1=cluster number;  
*** hh2=household number; 
*** ln=respondent's line number
gen double ind_id = hh1*100000 + hh2*100 + ln
format ind_id %20.0g
label var ind_id "Individual ID"


duplicates report ind_id


gen women_WM =1 
	//Identification variable for observations in WM recode



	//Retain relevant variables:	
keep wm17 wb4 cm1 cm8 cm9 cm10 ind_id women_WM 
order wm17 wb4 cm1 cm8 cm9 cm10 ind_id women_WM 
sort ind_id
save "$path_out/VNM21_WM.dta", replace


********************************************************************************
*** Step 1.4  MR - MEN'S RECODE  
***(All eligible man in the household) 
********************************************************************************

use "$path_in/mn.dta", clear 

rename _all, lower

	
*** Generate individual unique key variable required for data merging
*** hh1=cluster number;  
*** hh2=household number; 
*** ln=respondent's line number
gen double ind_id = hh1*100000 + hh2*100 + ln
format ind_id %20.0g
label var ind_id "Individual ID"

duplicates report ind_id

gen men_MN=1 	
	//Identification variable for observations in MR recode

	//Retain relevant variables:	
keep mcm1 mcm8 mcm9 mcm10 ind_id men_MN
 
order mcm1 mcm8 mcm9 mcm10 ind_id men_MN

sort ind_id

	//Save a temp file for merging with HL:
save "$path_out/VNM21_MN.dta", replace


********************************************************************************
*** Step 1.5 HH - HOUSEHOLD RECODE 
***(All households interviewed) 
********************************************************************************

use "$path_in/hh.dta", clear 

	
rename _all, lower	


*** Generate individual unique key variable required for data merging
*** hh1=cluster number;  
*** hh2=household number; 
gen	double hh_id = hh1*100 + hh2 
format	hh_id %20.0g
lab var hh_id "Household ID"


save "$path_out/VNM21_HH.dta", replace


********************************************************************************
*** Step 1.6 HL - HOUSEHOLD MEMBER  
********************************************************************************

use "$path_in/hl.dta", clear 
	
rename _all, lower


*** Generate a household unique key variable at the household level using: 
	***hh1=cluster number 
	***hh2=household number
gen double hh_id = hh1*100 + hh2 
format hh_id %20.0g
label var hh_id "Household ID"


*** Generate individual unique key variable required for data merging using:
	*** hh1=cluster number; 
	*** hh2=household number; 
	*** hl1=respondent's line number.
gen double ind_id = hh1*100000 + hh2*100 + hl1 
format ind_id %20.0g
label var ind_id "Individual ID"


sort ind_id
	
	
********************************************************************************
*** Step 1.7 DATA MERGING 
******************************************************************************** 
 
 
*** Merging BR Recode 
*****************************************
merge 1:1 ind_id using "$path_out/VNM21_BH.dta"
drop _merge
erase "$path_out/VNM21_BH.dta" 
 
 
*** Merging WM Recode 
*****************************************
merge 1:1 ind_id using "$path_out/VNM21_WM.dta"
drop _merge
erase "$path_out/VNM21_WM.dta"


*** Merging MN Recode 
*****************************************
merge 1:1 ind_id using "$path_out/VNM21_MN.dta"
drop _merge
erase "$path_out/VNM21_MN.dta"


*** Merging HH Recode 
*****************************************
merge m:1 hh_id using "$path_out/VNM21_HH.dta"
tab hh46 if _m==2
drop if _merge==2
	//Drop households that were not interviewed 
drop _merge
erase "$path_out/VNM21_HH.dta"



sort ind_id



********************************************************************************
*** Step 1.8 CONTROL VARIABLES
********************************************************************************


*** No Eligible Women 15-49 years
*****************************************
gen hl7=1 if hl8>0 & hl8<.
replace hl7=0 if hl8==0

gen fem_eligible = (hl7>0) if hl7!=.
	//Make sure that hl7>0 does not include hl7==. 
bys hh_id: egen hh_n_fem_eligible = sum(fem_eligible) 	
	//Number of eligible women for interview in the hh
gen no_fem_eligible = (hh_n_fem_eligible==0) 									
	//Takes value 1 if the household had no eligible females for an interview
lab var no_fem_eligible "Household has no eligible women"
drop hh_n_fem_eligible 
tab no_fem_eligible, m


*** No Eligible Men 
*****************************************

gen male_eligible = (hl9>0) if hl9!=.
bys hh_id: egen hh_n_male_eligible = sum(male_eligible)  
	//Number of eligible men for interview in the hh
gen no_male_eligible = (hh_n_male_eligible==0) 	
	//Takes value 1 if the household had no eligible males for an interview
lab var no_male_eligible "Household has no eligible men"
tab no_male_eligible, miss

	
*** No Eligible Children 0-5 years
***************************************** 
gen child_eligible = .	
gen no_child_eligible = .
lab var no_child_eligible "Household has no children eligible"	

sort hh_id

********************************************************************************
*** Step 1.9 RENAMING DEMOGRAPHIC VARIABLES ***
********************************************************************************

//Sample weight
clonevar weight = hhweight 
label var weight "Sample weight"


//Area: urban or rural		
desc hh6	
clonevar area = hh6  
replace area=0 if area==2  
label define lab_area 1 "urban" 0 "rural"
label values area lab_area
label var area "Area: urban-rural"


//Relationship to the head of household
desc hl3
clonevar relationship = hl3 
codebook relationship, tab (20)
recode relationship (1=1)(2=2)(3=3)(13=3)(4/12=4)(14=6)(96=5)(98/99=.)
label define lab_rel 1"head" 2"spouse" 3"child" 4"extended family" 5"not related" 6"maid"
label values relationship lab_rel
label var relationship "Relationship to the head of household"
tab hl3 relationship, miss	


//Sex of household member
codebook hl4
clonevar sex = hl4 
label var sex "Sex of household member"


//Age of household member
codebook hl6, tab (999)
clonevar age = hl6  
replace age = . if age>=98
label var age "Age of household member"


//Age group 
recode age (0/4 = 1 "0-4")(5/9 = 2 "5-9")(10/14 = 3 "10-14") ///
		   (15/17 = 4 "15-17")(18/59 = 5 "18-59")(60/max=6 "60+"), gen(agec7)
lab var agec7 "age groups (7 groups)"	
	   
recode age (0/9 = 1 "0-9") (10/17 = 2 "10-17")(18/59 = 3 "18-59") ///
		   (60/max=4 "60+"), gen(agec4)
lab var agec4 "age groups (4 groups)"

recode age (0/17 = 1 "0-17") (18/max = 2 "18+"), gen(agec2)		 		   
lab var agec2 "age groups (2 groups)"


//Total number of hh members in the household
gen member = 1
bysort hh_id: egen hhsize = sum(member)
label var hhsize "Household size"
tab hhsize, miss
drop member
compare hhsize hh48


//Subnational region
lookfor region
codebook hh7, tab (100)
gen region = hh7
lab var region "Region for subnational decomposition"
tab hh7 region, m


********************************************************************************
***  Step 2 Data preparation  ***
***  Standardization of the 10 Global MPI indicators 
***  Identification of non-deprived & deprived individuals  
********************************************************************************


********************************************************************************
*** Step 2.1 Years of Schooling ***
********************************************************************************
** official school entrance age: 6 yrs
** official duration of primary school: 5 yrs

tab ed5b ed5a, miss
codebook ed5b ed5a ed4, tab (30)
tab age ed10a if ed9==1, m
	//Check: For those currently in school, check their level of schooling

gen eduyears=1 if ed5b==1 & ed5a==1
replace eduyears=2 if ed5b==2 & ed5a==1
replace eduyears=3 if ed5b==3 & ed5a==1
replace eduyears=4 if ed5b==4 & ed5a==1
replace eduyears=5 if ed5b==5 & ed5a==1

replace eduyears=6 if ed5b==6 & ed5a==2
replace eduyears=7 if ed5b==7 & ed5a==2
replace eduyears=8 if ed5b==8 & ed5a==2
replace eduyears=9 if ed5b==9 & ed5a==2

replace eduyears=10 if ed5b==10 & ed5a==3
replace eduyears=11 if ed5b==11 & ed5a==3
replace eduyears=12 if ed5b==12 & ed5a==3

replace eduyears=11 if ed5a==4
replace eduyears=14 if ed5a==5


replace eduyears=0 if ed5a==0 | ed4==2

replace eduyears=2 if ed5a==8 & ed5b==2
replace eduyears=4 if ed5a==8 & ed5b==4
replace eduyears=5 if ed5a==8 & ed5b==5
replace eduyears=6 if ed5a==8 & ed5b==6
replace eduyears=12 if ed5a==8 & ed5b==12

replace eduyears = eduyears-1 if ed6==2 & eduyears>0 & eduyears<. 
/* rest 1 year of schooling to those who did not complete the highest level attended */ 

lab var eduyears "Highest year of education completed"

replace eduyears=6 if (ed5a>=3 & ed5a<=5) & (ed5b==98 | ed5b==99)
** imputing 6 years, we do not know how many years they completed but they completed 6 at least so for MPI they are not deprived

tab eduyears ed5a, m

*** Cleaning inconsistencies 
replace eduyears = . if age<=eduyears & age>0 
	/*There are cases in which the years of schooling are greater than the 
	age of the individual. This is clearly a mistake in the data. Please check 
	whether this is the case and correct when necessary */
replace eduyears = 0 if age < 10
/*The variable "eduyears" was replaced with a '0' given that the criteria 
	for this indicator is household member aged 10 years or older */
replace eduyears = 0 if (age==10 | age==11) & eduyears < 6
	/*The variable "eduyears" was replaced with a '0' given that the criteria 
	for this indicator is household member aged 12 years or older */

	
	/*A control variable is created on whether there is information on 
	years of education for at least 2/3 of the household members. */
gen temp = 1 if (eduyears!=. & (age>=12 & age!=.)) | (((age==10 | age==11) & eduyears>=6 & eduyears<.))
bysort	hh_id: egen no_missing_edu = sum(temp)
	/*Total household members who are 11 years and older with no missing 
	years of education but recognizing as an achievement if the member is 10 or 11 and already completed 6 yrs of schooling */
gen temp2 = 1 if (age>=12 & age!=.) | (((age==10 | age==11) & eduyears>=6 & eduyears<.))
bysort hh_id: egen hhs = sum(temp2)
	//Total number of household members who are 12 years and older 
replace no_missing_edu = no_missing_edu/hhs
replace no_missing_edu = (no_missing_edu>=2/3)
	/*Identify whether there is information on years of education for at 
	least 2/3 of the household members aged 12 years and older */
tab no_missing_edu, miss
label var no_missing_edu "No missing edu for at least 2/3 of the HH members aged 12 years & older"		
drop temp temp2 hhs


/*The entire household is considered deprived if no household member aged 12 years or older has completed SIX years of schooling. */

gen	 years_edu6 = (eduyears>=6)
	/* The years of schooling indicator takes a value of "1" if at least someone 
	in the hh has reported 6 years of education or more */
replace years_edu6 = . if eduyears==.
bysort hh_id: egen hh_years_edu6_1 = max(years_edu6)
gen	hh_years_edu6 = (hh_years_edu6_1==1)
replace hh_years_edu6 = . if hh_years_edu6_1==.
replace hh_years_edu6 = . if hh_years_edu6==0 & no_missing_edu==0 
lab var hh_years_edu6 "Household has at least one member with 6 years of edu"


********************************************************************************
*** Step 2.2 Child School Attendance ***
********************************************************************************

gen attendance = 1 if ed9==1 
	//Replace attendance with '1' if currently attending school
replace attendance = 0 if ed9==2 
	//Replace attendance with '0' if currently not attending school
replace attendance = 0 if ed4==2
	//Replace attendance with '0' if never ever attended school

tab age ed9, miss	
	//Check individuals who are not of school age
	
replace attendance = 0 if age<5 | age>24 
	//Replace attendance with '0' for individuals who are not of school age 
		
tab attendance, m


*** Standard MPI ***
/*The entire household is considered deprived if any school-aged 
child is not attending school up to class 8. */ 
******************************************************************* 
gen child_schoolage = (schage>=6 & schage<=14)
	/*Note: In Vietnam, the official school entrance age for primary 
	school is 6 years. So, age range is 6-14 (=6+8)*/

	
	/*A control variable is created on whether there is no information on 
	school attendance for at least 2/3 of the school age children */
count if child_schoolage==1 & attendance==.	
gen temp = 1 if child_schoolage==1 & attendance!=.
bysort hh_id: egen no_missing_atten = sum(temp)	
gen temp2 = 1 if child_schoolage==1	
bysort hh_id: egen hhs = sum(temp2)
replace no_missing_atten = no_missing_atten/hhs 
replace no_missing_atten = (no_missing_atten>=2/3)	
tab no_missing_atten, miss
label var no_missing_atten "No missing school attendance for at least 2/3 of the school aged children"		
drop temp temp2 hhs
	
	
bysort	hh_id: egen hh_children_schoolage = sum(child_schoolage)
replace hh_children_schoolage = (hh_children_schoolage>0) 
lab var hh_children_schoolage "Household has children in school age"


gen	child_not_atten = (attendance==0) if child_schoolage==1
replace child_not_atten = . if attendance==. & child_schoolage==1
bysort	hh_id: egen any_child_not_atten = max(child_not_atten)
gen	hh_child_atten = (any_child_not_atten==0) 
replace hh_child_atten = . if any_child_not_atten==.
replace hh_child_atten = 1 if hh_children_schoolage==0
replace hh_child_atten = . if hh_child_atten==1 & no_missing_atten==0 
lab var hh_child_atten "Household has all school age children up to class 8 in school"
tab hh_child_atten, m



********************************************************************************
*** Step 2.3 Nutrition ***
********************************************************************************
 
	/*This survey has no information on nutrition. As such, the final 
	sets of nutrition indicators in this survey, generated as part of 
	the global MPI task are assigned with missing observations */
	
	
gen underweight = .
lab var underweight  "Child is undernourished (weight-for-age) 2sd - WHO"

gen stunting=.
lab var stunting "Child is stunted (length/height-for-age) 2sd - WHO"

gen wasting=.
lab var wasting  "Child is wasted (weight-for-length/height) 2sd - WHO"

gen hh_no_underweight = .
lab var hh_no_underweight "Household has no child underweight - 2 stdev"

gen hh_no_stunting  = .
lab var hh_no_stunting "Household has no child stunted - 2 stdev"

gen hh_no_wasting = .
lab var hh_no_wasting "Household has no child wasted - 2 stdev"

gen hh_no_uw_st = .
lab var hh_no_uw_st "Household has no child underweight or stunted"

gen hh_nutrition_uw_st = .
lab var hh_nutrition_uw_st "Household has no child underweight/stunted or adult deprived by BMI/BMI-for-age"

gen weight_ch = .
label var weight_ch "sample weight child under 5"


********************************************************************************
*** Step 2.4 Child Mortality ***
********************************************************************************

codebook cm9 cm10 
	//cm9 or cm10: number of sons/daugters who have died provided by women

	
replace cm1=1 if cm8==1 & cm1==2
egen temp_f = rowtotal(cm9 cm10), missing
	//Total child mortality reported by eligible women
replace temp_f = 0 if (cm1==1 & cm8==2) | cm1==2 
	/*Assign a value of "0" for:
	- all eligible women who have ever gave birth but reported no child death 
	- all eligible women who never ever gave birth */
*replace temp_f = 0 if cm1==. & cm8==. & marital==1 & temp_f==. & women_WM==1

*replace temp_f = 0 if no_fem_eligible==1	
	/*Assign a value of "0" for:
	- individuals living in households that have non-eligible women */
bysort	hh_id: egen child_mortality_f = sum(temp_f), missing
lab var child_mortality_f "Occurrence of child mortality reported by women"
tab child_mortality_f, miss
drop temp_f
	

replace mcm1=1 if mcm8==1 & mcm1==2
egen temp_m = rowtotal(mcm9 mcm10), missing
	//Total child mortality reported by eligible men	
replace temp_m = 0 if (mcm1==1 & mcm8==2) | mcm1==2 
	/*Assign a value of "0" for:
	- all eligible men who ever fathered children but reported no child death 
	- all eligible men who never fathered children */
*replace temp_m = 0 if mcm1==. & mcm8==. & marital_men==1 & temp_m==. & men_MN==1 

*replace temp_m = 0 if no_male_eligible==1	
	/*Assign a value of "0" for:
	- individuals living in households that have non-eligible men */
bysort	hh_id: egen child_mortality_m = sum(temp_m), missing	
lab var child_mortality_m "Occurrence of child mortality reported by men"
tab child_mortality_m, miss
drop temp_m

egen child_mortality = rowmax(child_mortality_f child_mortality_m)
replace child_mortality = 0 if no_fem_eligible==1 & no_male_eligible==1
lab var child_mortality "Total child mortality within household reported by women"

tab child_mortality, miss
replace child_mortality=0 if no_fem_eligible==1 & no_male_eligible==1

gen hh_mortality = (child_mortality==0)
replace hh_mortality = . if child_mortality==.
tab hh_mortality, miss	
lab var hh_mortality "Household had no child mortality any time"

/*Deprived if any children died in the household in the last 5 years 
from the survey year */
************************************************************************

tab child_died_per_wom_5y, miss
	/* The 'child_died_per_wom_5y' variable was constructed in Step 1.2 using 
	information from individual women who ever gave birth in the BR file. The 
	missing values represent eligible woman who have never ever given birth and 
	so are not present in the BR file. But these 'missing women' may be living 
	in households where there are other women with child mortality information 
	from the BR file. So at this stage, it is important that we aggregate the 
	information that was obtained from the BR file at the household level. This
	ensures that women who were not present in the BR file is assigned with a 
	value, following the information provided by other women in the household.*/
		
replace child_died_per_wom_5y = 0 if cm1==2
replace child_died_per_wom_5y = 0 if cm1==1 & cm8==2 & child_died_per_wom_5y==.
	/*Assign a value of "0" for:
	- all eligible women who never ever gave birth */
*replace child_died_per_wom_5y=0 if women_WM==1 & marital==1 & child_died_per_wom_5y==.
/* never married women were not interviewed, we assume they are not deprived in child mortality */
replace child_died_per_wom_5y = 0 if no_fem_eligible==1	
	/*Assign a value of "0" for:
	- individuals living in households that have non-eligible women */
	
bysort hh_id: egen child_mortality_5y = sum(child_died_per_wom_5y), missing

replace child_mortality_5y = 0 if child_mortality_5y==. & child_mortality_m==0
	/*Replace all households as 0 death if women has missing value and men 
	reported no death in those households */
	
label var child_mortality_5y "Total child mortality within household past 5 years reported by women"
tab child_mortality_5y, miss

	
	/*
	The new standard MPI indicator takes a value of "1" if eligible women  
	within the household reported no child mortality or if any child died longer 
	than 5 years from the survey year. The indicator takes a value of "0" if 
	women in the household reported any child mortality in the last 5 years from 
	the survey year. Households were replaced with a value of "1" if eligible 
	men within the household reported no child mortality in the absence of 
	information from women. The indicator takes a missing value if there was 
	missing information on reported death from eligible individuals.
	*/
	
	
gen hh_mortality_5y = (child_mortality_5y==0)
replace hh_mortality_5y = . if child_mortality_5y==.
tab hh_mortality_5y, miss	
lab var hh_mortality_5y "Household had no child mortality in the last 5 years"


********************************************************************************
*** Step 2.5 Electricity ***
********************************************************************************


*** Standard MPI ***
/*Members of the household are considered 
deprived if the household has no electricity */
***************************************************
clonevar electricity = hc8 
replace electricity = 1 if electricity==2
replace electricity = 0 if electricity==3
replace electricity = . if electricity==9 	
label var electricity "Household has electricity"


********************************************************************************
*** Step 2.6 Sanitation ***
********************************************************************************
/*
Improved sanitation facilities include flush or pour flush toilets to sewer 
systems, septic tanks or pit latrines, ventilated improved pit latrines, pit 
latrines with a slab, and composting toilets. These facilities are only 
considered improved if it is private, that is, it is not shared with other 
households.
Source: https://unstats.un.org/sdgs/metadata/files/Metadata-06-02-01.pdf

Note: In cases of mismatch between the country report and the internationally 
agreed guideline, we followed the report.
*/
	

gen toilet_mdg = 0 if ws11==14 | ws11==23 | ws11==41 | ws11==51 | ws11==95 | ws11==96
replace toilet_mdg = 1 if ws11==11 | ws11==12 | ws11==13 | ws11==18 | ws11==21 | ws11==22 | ws11==31
replace toilet_mdg = 0 if ws15==1 /*shared*/
/*Household is assigned a value of '0' if it uses improved sanitation 
	but shares toilet with other households  */
lab var toilet_mdg "Household has improved sanitation with MDG Standards"
tab ws11 toilet_mdg, miss


/*              Type of toilet facility |      Freq.     Percent        Cum.
----------------------------------------+-----------------------------------
FLUSH / POUR FLUSH: FLUSH TO PIPED SEWE |      1,368        2.86        2.86 11 y
FLUSH / POUR FLUSH: FLUSH TO SEPTIC TAN |     32,373       67.70       70.56 12 y
FLUSH / POUR FLUSH: FLUSH TO PIT LATRIN |      2,931        6.13       76.69 13 y
FLUSH / POUR FLUSH: FLUSH TO OPEN DRAIN |        349        0.73       77.42 14 n
  FLUSH / POUR FLUSH: FLUSH TO DK WHERE |        103        0.22       77.63 18 y
PIT LATRINE: VENTILATED IMPROVED PIT LA |        204        0.43       78.06 21 y
     PIT LATRINE: PIT LATRINE WITH SLAB |      2,940        6.15       84.21 22 y
PIT LATRINE: PIT LATRINE WITHOUT SLAB / |        856        1.79       86.00 23 n
                      COMPOSTING TOILET |        729        1.52       87.52 31 y
                                 BUCKET |        141        0.29       87.81 41 n
       HANGING TOILET / HANGING LATRINE |      1,882        3.94       91.75 51 n
             NO FACILITY / BUSH / FIELD |      3,781        7.91       99.66 95 n
                                  OTHER |        142        0.30       99.95 96 n
                            NO RESPONSE |         22        0.05      100.00 99 .
----------------------------------------+-----------------------------------
                                  Total |     47,821      100.00 */

********************************************************************************
*** Step 2.7 Drinking Water  ***
********************************************************************************
/*
Improved drinking water sources include the following: piped water into 
dwelling, yard or plot; public taps or standpipes; boreholes or tubewells; 
protected dug wells; protected springs; packaged water; delivered water and 
rainwater which is located on premises or is less than a 30-minute walk from 
home roundtrip. 
Source: https://unstats.un.org/sdgs/metadata/files/Metadata-06-01-01.pdf

Note: In cases of mismatch between the country report and the internationally 
agreed guideline, we followed the report.
*/	

gen water_mdg = 1 if ws1==11 | ws1==12 | ws1==13 | ws1==14 | ws1==21 | ws1==31 | ws1==41 | ws1==51 | ws1==61 | ws1==71 | ws1==91 | ws1==92
replace water_mdg = 0 if ws1==32 | ws1==42 | ws1==81 | ws1==96
replace water_mdg = 0 if ws4>= 30 & ws4!=. & ws4!=998 & ws4!=999 

lab var water_mdg "Household has drinking water with MDG standards (considering distance)"
tab ws1 water_mdg, miss


/*        Main source of drinking water |      Freq.     Percent        Cum.
----------------------------------------+-----------------------------------
       PIPED WATER: PIPED INTO DWELLING |     12,107       25.32       25.32 11 y
      PIPED WATER: PIPED TO YARD / PLOT |      1,013        2.12       27.44 12 y
        PIPED WATER: PIPED TO NEIGHBOUR |         77        0.16       27.60 13 y
    PIPED WATER: PUBLIC TAP / STANDPIPE |        109        0.23       27.82 14 y
                   TUBE WELL / BOREHOLE |      6,229       13.03       40.85 21 y
               DUG WELL: PROTECTED WELL |      5,419       11.33       52.18 31 y
             DUG WELL: UNPROTECTED WELL |        421        0.88       53.06 32 n
               SPRING: PROTECTED SPRING |      6,494       13.58       66.64 41 y
             SPRING: UNPROTECTED SPRING |      1,418        2.97       69.61 42 n
                              RAINWATER |      4,399        9.20       78.81 51 y
                           TANKER-TRUCK |         10        0.02       78.83 61 y
SURFACE WATER (RIVER, DAM, LAKE, POND,  |        101        0.21       79.04 81 n
          PACKAGED WATER: BOTTLED WATER |      9,758       20.41       99.44 91 y
           PACKAGED WATER: SACHET WATER |         80        0.17       99.61 92 y
                                  OTHER |        162        0.34       99.95 96 n
                            NO RESPONSE |         24        0.05      100.00 99 .
----------------------------------------+-----------------------------------
                                  Total |     47,821      100.00          */

********************************************************************************
*** Step 2.8 Housing ***
********************************************************************************

/* Members of the household are considered deprived if the household 
has a dirt, sand or dung floor */
clonevar floor = hc4
codebook floor, tab(99)
gen floor_imp = 1
replace floor_imp = 0 if floor<=12 | floor==96  	
replace floor_imp = . if floor==. | floor==99 
lab var floor_imp "Household has floor that it is not earth/sand/dung"
ta hc4 floor_imp,m


/* Members of the household are considered deprived if the household has wall 
made of natural or rudimentary materials */
clonevar wall = hc6
codebook wall, tab(99)	
gen wall_imp = 1 
replace wall_imp = 0 if wall<=28 | wall==96  	
replace wall_imp = . if wall==. | wall==99 	
lab var wall_imp "Household has wall that it is not of low quality materials"
ta hc6 wall_imp,m


/* Members of the household are considered deprived if the household has roof 
made of natural or rudimentary materials */
clonevar roof = hc5
codebook roof, tab(99)	
gen roof_imp = 1 
replace roof_imp = 0 if roof<=25 | roof==96  	
replace roof_imp = . if roof==. | roof==99 
lab var roof_imp "Household has roof that it is not of low quality materials"
tab hc5 roof_imp, m


/*Household is deprived in housing if the roof, floor OR walls uses 
low quality materials.*/
gen housing_1 = 1
replace housing_1 = 0 if floor_imp==0 | wall_imp==0 | roof_imp==0
replace housing_1 = . if floor_imp==. & wall_imp==. & roof_imp==.
lab var housing_1 "Household has roof, floor & walls that it is not low quality material"
tab housing_1, m


********************************************************************************
*** Step 2.9 Cooking Fuel ***
********************************************************************************
/*
Solid fuel are solid materials burned as fuels, which includes coal as well as 
solid biomass fuels (wood, animal dung, crop wastes and charcoal). 

Source: 
https://apps.who.int/iris/bitstream/handle/10665/141496/9789241548885_eng.pdf
*/

clonevar cookingfuel = eu1  
codebook cookingfuel, tab(99)

gen cooking_mdg = 1 if cookingfuel<=5 | cookingfuel==97
replace cooking_mdg = 0 if cookingfuel>5 & cookingfuel<=96 
replace cooking_mdg = 1 if (cookingfuel>=6 & cookingfuel<=10) & (eu4==1 | eu4==2 | eu4==3)
lab var cooking_mdg "Household has cooking fuel by MDG standards"
	/* Deprived if: "coal/lignite", "charcoal", "wood", "straw/shrubs/grass" 
					"agricultural crop", "animal dung" */			 
bys cooking_mdg: ta eu1 eu4, m


********************************************************************************
*** Step 2.10 Assets ownership ***
********************************************************************************

codebook hc11 hc7a hc12 hc9a hc9b hc9c hc10b hc10c hc10d hc10e hc10f
	//hc8q not available.

clonevar television = hc9b
gen bw_television = .
clonevar radio = hc9a
clonevar telephone = hc7a
clonevar mobiletelephone = hc12
clonevar refrigerator = hc9c 
clonevar car = hc10f
gen bicycle = 1 if hc10b==1 | hc10c==1 
replace bicycle=0 if hc10b==2 & hc10c==2
clonevar motorbike = hc10d
clonevar computer = hc11
clonevar animal_cart = hc10e

foreach var in television radio telephone mobiletelephone refrigerator car bicycle motorbike computer animal_cart {
replace `var' = 0 if `var'==2 
replace `var' = . if `var'==9 | `var'==99 | `var'==8 | `var'==98 
}
	

	//Group telephone and mobiletelephone as a single variable
replace telephone=1 if mobiletelephone==1

/* Members of the household are considered deprived in assets if the household 
does not own more than one of: radio, TV, telephone, bike, motorbike, 
refrigerator, computer or animal_cart and does not own a car or truck.*/

egen n_small_assets2 = rowtotal(television radio telephone refrigerator bicycle motorbike computer animal_cart), missing
lab var n_small_assets2 "Household Number of Small Assets Owned" 
  
  
gen hh_assets2 = (car==1 | n_small_assets2 > 1) 
replace hh_assets2 = . if car==. & n_small_assets2==.
lab var hh_assets2 "Household Asset Ownership: HH has car or more than 1 small assets incl computer & animal cart"


********************************************************************************
*** Step 2.11 Rename and keep variables for MPI calculation 
********************************************************************************
	

	//Retain data on sampling design: 
desc psu stratum
rename stratum strata
label var psu "Primary sampling unit"
label var strata "Sample strata"	


	//Retain year, month & date of interview:
desc hh5y hh5m hh5d 
clonevar year_interview = hh5y 	
clonevar month_interview = hh5m 
clonevar date_interview = hh5d 
 
 
	//Generate presence of subsample
gen subsample = .
 


*** Rename key global MPI indicators for estimation ***
recode hh_mortality_5y  (0=1)(1=0) , gen(d_cm)
recode hh_nutrition_uw_st 	(0=1)(1=0) , gen(d_nutr)
recode hh_child_atten 		(0=1)(1=0) , gen(d_satt)
recode hh_years_edu6 		(0=1)(1=0) , gen(d_educ)
recode electricity 			(0=1)(1=0) , gen(d_elct)
recode water_mdg 			(0=1)(1=0) , gen(d_wtr)
recode toilet_mdg 			(0=1)(1=0) , gen(d_sani)
recode housing_1 			(0=1)(1=0) , gen(d_hsg)
recode cooking_mdg 			(0=1)(1=0) , gen(d_ckfl)
recode hh_assets2 			(0=1)(1=0) , gen(d_asst)


	/*In this survey, the harmonised 'region_01' variable is the 
	same as the standardised 'region' variable.*/	
clonevar region_01 = region 


*** Keep main variables require for MPI calculation ***
keep hh_id ind_id subsample psu weight area relationship sex age agec7 agec4 hhsize region date_interview d_cm d_nutr d_satt d_educ d_elct d_wtr d_sani d_hsg d_ckfl d_asst hh_mortality_5y hh_nutrition_uw_st hh_child_atten hh_years_edu6 electricity water_mdg toilet_mdg housing_1 cooking_mdg hh_assets2 

order hh_id ind_id subsample psu weight area relationship sex age agec7 agec4 hhsize region date_interview d_cm d_nutr d_satt d_educ d_elct d_wtr d_sani d_hsg d_ckfl d_asst hh_mortality_5y hh_nutrition_uw_st hh_child_atten hh_years_edu6 electricity water_mdg toilet_mdg housing_1 cooking_mdg hh_assets2



*** Generate coutry and survey details for estimation ***
char _dta[cty] "Vietnam"
char _dta[ccty] "VNM"
char _dta[year] "2020-2021" 	
char _dta[survey] "MICS"
char _dta[ccnum] "704"
char _dta[type] "micro"
char _dta[class] "old_survey"


*** Sort, compress and save data for estimation ***
sort ind_id
compress
la da "Micro data for `_dta[ccty]' (`_dta[ccnum]') from `c(current_date)' (`c(current_time)')."
save "$path_out/vnm_mics20-21.dta", replace 



********************************************************************************
*** MPI Calculation (TTD file)
********************************************************************************

**SELECT COUNTRY POV FILE RUN ON LOOP FOR MORE COUNTRIES

use "$path_out\vnm_mics20-21.dta", clear

********************************************************************************
*** Define Sample Weight and total population ***
********************************************************************************
gen sample_weight = weight/1000000 
	//only DHS


gen country = "Viet Nam" 
gen countrycode = "VNM"  


/* change to weight if MICS*/
	
********************************************************************************
*** List of the 10 indicators included in the MPI ***
********************************************************************************

gen edu_1 = hh_years_edu6
gen atten_1 = hh_child_atten
gen cm_1 = hh_mortality_5y
/* change countries with no child mortality 5 year to child mortality ever*/
gen nutri_1 = hh_nutrition_uw_st
gen elec_1 = electricity
gen toilet_1 = toilet_mdg
gen water_1 = water_mdg
gen house_1 = housing_1
gen fuel_1 = cooking_mdg
gen asset_1 = hh_assets2

global est_1 edu_1 atten_1 cm_1 elec_1 toilet_1 water_1 house_1 fuel_1 asset_1

********************************************************************************
*** List of sample without missing values ***
********************************************************************************

foreach j of numlist 1 {
gen sample_`j' = (edu_`j'!=. & atten_`j'!=. & cm_`j'!=. & elec_`j'!=. & toilet_`j'!=. & water_`j'!=. & house_`j'!=. & fuel_`j'!=. & asset_`j'!=.)

replace sample_`j' = . if subsample==0
	/* Note: If the anthropometric data was collected from a subsample of the 
	total population that was sampled, then the final analysis only includes the 
	subsample population. */ 

*** Percentage sample after dropping missing values ***
sum sample_`j' [iw = sample_weight]
gen per_sample_weighted_`j' = r(mean)

sum sample_`j'
gen per_sample_`j' = r(mean)
}
***

********************************************************************************
*** Define deprivation matrix 'g0' 
*** which takes values 1 if individual is deprived in the particular 
*** indicator according to deprivation cutoff z as defined during step 2 ***
********************************************************************************
foreach j of numlist 1 {
foreach var in ${est_`j'} {  
	gen	g0`j'_`var' = 1 if `var'==0
	replace g0`j'_`var' = 0 if `var'==1
	}
}
	
*** Raw Headcount Ratios
foreach j of numlist 1 {
foreach var in ${est_`j'}   {  
	sum	g0`j'_`var' if sample_`j'==1 [iw = sample_weight]
	gen	raw`j'_`var' = r(mean)*100
	lab var raw`j'_`var'  "Raw Headcount: Percentage of people who are deprived in `var'"
	}
}
********************************************************************************
*** Define vector 'w' of dimensional and indicator weight ***
********************************************************************************
/*If survey lacks one or more indicators, weights need to be adjusted within /
each dimension such that each dimension weighs 1/3 and the indicator weights
add up to one (100%). CHECK COUNTRY FILE*/

foreach j of numlist 1 {
// DIMENSION EDUCATION 
foreach var in edu_`j' atten_`j' {
capture drop w`j'_`var' 
	gen w`j'_`var' = 1/6
	}

// DIMENSION HEALTH
foreach var in cm_`j' {
	capture drop w`j'_`var'
	gen w`j'_`var' = 1/3
	}

// DIMENSION LIVING STANDARD
foreach var in elec_`j' toilet_`j' water_`j' house_`j' fuel_`j' asset_`j' {
	
	capture drop w`j'_`var'
	gen w`j'_`var' = 1/18
	}

}
********************************************************************************
*** Generate the weighted deprivation matrix 'w' * 'g0'
********************************************************************************

foreach j of numlist 1 {
foreach var in ${est_`j'} {
	gen	w`j'_g0_`var' = w`j'_`var' * g0`j'_`var' 
	replace w`j'_g0_`var' = . if sample_`j'!=1 
	/*The estimation is based only on observations that have non-missing values 
	for all variables in varlist_pov*/
	}
}
********************************************************************************
*** Generate the vector of individual weighted deprivation count 'c'
********************************************************************************

foreach j of numlist 1 {
egen	c_vector_`j' = rowtotal(w`j'_g0_*)
replace c_vector_`j' = . if sample_`j'!=1
*drop	w_g0_*
}

********************************************************************************
*** Identification step according to poverty cutoff k (20 33.33 50) ***
********************************************************************************

foreach j of numlist 1 {
	foreach k of numlist 20 33 50 {
		gen	multidimensionally_poor_`j'_`k' = (c_vector_`j'>=`k'/100)
		replace multidimensionally_poor_`j'_`k' = . if sample_`j'!=1 
		//Takes value 1 if individual is multidimensional poor
	}
}

********************************************************************************
*** Generate the censored vector of individual weighted deprivation count 'c(k)'
********************************************************************************


foreach j of numlist 1 {
	foreach k of numlist 20 33 50 {
		gen	c_censured_vector_`j'_`k' = c_vector_`j'
		replace c_censured_vector_`j'_`k' = 0 if multidimensionally_poor_`j'_`k'==0 
	}	//Provide a score of zero if a person is not poor
}
*

********************************************************************************
*** Define censored deprivation matrix 'g0(k)' ***
********************************************************************************

foreach j of numlist 1 {
foreach var in ${est_`j'} {
	gen	g0`j'_k_`var' = g0`j'_`var' 
	replace g0`j'_k_`var' = 0 if multidimensionally_poor_`j'_33==0
	replace g0`j'_k_`var' = . if sample_`j'!=1 
	}
}	
********************************************************************************
*** Generates Multidimensional Poverty Index (MPI), 
*** Headcount (H) and Intensity of Poverty (A) ***
********************************************************************************

*** Multidimensional Poverty Index (MPI) ***
foreach j of numlist 1 {
	foreach k of numlist 20 33 50 {
		sum	c_censured_vector_`j'_`k' [iw = sample_weight] if sample_`j'==1
		gen	MPI_`j'_`k' = r(mean)
		lab var MPI_`j'_`k' "MPI with k=`k'"
	}
	
	sum	c_censured_vector_`j'_33 [iw = sample_weight] if sample_`j'==1
	gen	MPI_`j' = r(mean)
	lab var MPI_`j' "`j' Multidimensional Poverty Index (MPI = H*A): Range 0 to 1"

*** Headcount (H) ***
	sum	multidimensionally_poor_`j'_33 [iw = sample_weight] if sample_`j'==1
	gen	H_`j' = r(mean)*100
	lab var H_`j' "`j' Headcount ratio: % Population in multidimensional poverty (H)"

*** Intensity of Poverty (A) ***
	sum	c_censured_vector_`j'_33 [iw = sample_weight] if multidimensionally_poor_`j'_33==1 & sample_`j'==1
	gen	A_`j' = r(mean)*100
	lab var A_`j'  "`j' Intensity of deprivation among the poor (A): Average % of weighted deprivations"

*** Population vulnerable to poverty (who experience 20-32.9% intensity of deprivations) ***
	gen	temp = 0
	replace temp = 1 if c_vector_`j'>=0.2 & c_vector_`j'<0.3332
	replace temp = . if sample_`j'!=1
	sum	temp [iw = sample_weight] 
	gen	vulnerable_`j' = r(mean)*100
	lab var vulnerable_`j'  "`j' % Population vulnerable to poverty (who experience 20-32.9% intensity of deprivations)"
	drop	temp

*** Population in severe poverty (with intensity 50% or higher) *** 
	gen	temp = 0
	replace temp = 1 if c_vector_`j'>0.49
	replace temp = . if sample_`j'!=1
	sum	temp [iw = sample_weight] 
	gen	severe_`j' = r(mean)*100
	lab var severe_`j'  "`j' % Population in severe poverty (with intensity 50% or higher)"
	drop	temp	
}
*

*** Censored Headcount ***

foreach j of numlist 1 {
foreach var in ${est_`j'} {
	sum	g0`j'_k_`var' [iw = sample_weight] if sample_`j'==1
	gen	cen`j'_`var' = r(mean)*100 
	lab var cen`j'_`var'  "Censored Headcount: Percentage of people who are poor and deprived in `var'"
	}
}
*** Dimensional Contribution ***

foreach j of numlist 1 {
foreach var in ${est_`j'} {	
gen	cont`j'_`var' = (w`j'_`var' * cen`j'_`var')/MPI_`j' if sample_`j'==1
	lab var cont`j'_`var'  "% Contribution in MPI of indicator..."
	}
}

** The line below produces the variance (inequality among the poor) ** 
sum c_vector_1 if c_vector_1>=1/3 & c_vector_1<=1 [aw = sample_weight], detail
gen var=r(Var)

*** Prepare results to export ***
keep subsample country per_sample_weighted* per_sample* MPI* H* A* vulnerable* severe* raw* cen* cont* var


order MPI_1 H_1 A_1 var severe_1 vulnerable_1 cont1_cm_1 cont1_edu_1 cont1_atten_1 cont1_fuel_1 cont1_toilet_1 cont1_water_1 cont1_elec_1 cont1_house_1 cont1_asset_1 per_sample_1 per_sample_weighted_1 raw1_cm_1 raw1_edu_1 raw1_atten_1 raw1_fuel_1 raw1_toilet_1 raw1_water_1 raw1_elec_1 raw1_house_1 raw1_asset_1 cen1_cm_1 cen1_edu_1 cen1_atten_1 cen1_fuel_1 cen1_toilet_1 cen1_water_1 cen1_elec_1 cen1_house_1 cen1_asset_1

codebook, compact

