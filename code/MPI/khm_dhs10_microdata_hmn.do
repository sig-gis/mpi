********************************************************************************
/*
Adapted from:
Oxford Poverty and Human Development Initiative (OPHI), University of Oxford. 
2021 Global Multidimensional Poverty Index - Cambodia DHS 2010 [STATA do-file]. 
Available from OPHI website: http://ophi.org.uk/  

For further queries, contact: ophi@qeh.ox.ac.uk
*/
********************************************************************************

clear all 
set more off

cd "C:\Users\tianc\OneDrive\Documents\SIG\DISES\code\MPI"
*** Working Folder Path ***
global path_in "../../data/MPI/khm_dhs10_cot" 	  
global path_out "../../data/MPI/khm_hmn"
global path_ado "ado"

	
********************************************************************************
*** CAMBODIA DHS 2010 ***
********************************************************************************

/* This script excludes wall material from the housing indicator. Step 1 is
skipped as it would be the same as in `khm_dhs10_microdata_cot.do`. */

********************************************************************************
***  Step 2 Data preparation  ***
***  Standardization of the 10 Global MPI indicators 
***  Identification of non-deprived & deprived individuals  
********************************************************************************

use "$path_in/KHM10_merged_procd.dta", clear 

********************************************************************************
*** Step 2.1 Years of Schooling ***
********************************************************************************

codebook hv108, tab(30)  // 1-25 in DHS 6, but 1-20 in DHS 5
clonevar  eduyears = hv108   
	//Total number of years of education
replace eduyears = . if eduyears>30
	//Recode any unreasonable years of highest education as missing value
replace eduyears = . if eduyears>=age & age>0
	/*The variable "eduyears" was replaced with a '.' if total years of 
	education was more than individual's age */
replace eduyears = 0 if age < 10 
	/*The variable "eduyears" was replaced with a '0' given that the criteria 
	for this indicator is household member aged 10 years or older */

	
	/*A control variable is created on whether there is information on 
	years of education for at least 2/3 of the household members aged 10 years 
	and older */	
gen temp = 1 if eduyears!=. & age>=10 & age!=.
bysort	hh_id: egen no_missing_edu = sum(temp)
	/*Total household members who are 10 years and older with no missing 
	years of education */
gen temp2 = 1 if age>=10 & age!=.
bysort hh_id: egen hhs = sum(temp2)
	//Total number of household members who are 10 years and older 
replace no_missing_edu = no_missing_edu/hhs
replace no_missing_edu = (no_missing_edu>=2/3)
	/*Identify whether there is information on years of education for at 
	least 2/3 of the household members aged 10 years and older */
tab no_missing_edu, miss
	//The value for 0 (missing) is 0.16% 
label var no_missing_edu "No missing edu for at least 2/3 of the eligible HH members"
drop temp temp2 hhs


*** Standard MPI ***
/*The entire household is considered deprived if no eligible 
household member has completed SIX years of schooling. */
******************************************************************* 
gen	 years_edu6 = (eduyears>=6)
replace years_edu6 = . if eduyears==.
bysort hh_id: egen hh_years_edu6_1 = max(years_edu6)
gen	hh_years_edu6 = (hh_years_edu6_1==1)
replace hh_years_edu6 = . if hh_years_edu6_1==.
replace hh_years_edu6 = . if hh_years_edu6==0 & no_missing_edu==0 
lab var hh_years_edu6 "Household has at least one member with 6 years of edu"

	
*** Destitution MPI ***
/*The entire household is considered deprived if no eligible 
household member has completed at least one year of schooling. */
******************************************************************* 
gen	years_edu1 = (eduyears>=1)
replace years_edu1 = . if eduyears==.
bysort	hh_id: egen hh_years_edu_u = max(years_edu1)
replace hh_years_edu_u = . if hh_years_edu_u==0 & no_missing_edu==0
lab var hh_years_edu_u "Household has at least one member with 1 year of edu"


********************************************************************************
*** Step 2.2 Child School Attendance ***
********************************************************************************

codebook hv121, tab (10)
clonevar attendance = hv121 
recode attendance (2=1) (9=.)
codebook attendance, tab (10)

label define lab_attend 1 "currently attending" 0 "not currently attending"
label values attendance lab_attend
label var attendance "Attended school during current school year"

replace attendance = 0 if (attendance==9 | attendance==.) & hv109==0 
// hv109 educational attainment
// not used in 2014 script, but (0 real changes made) here, so the inconsistency is ok

*** Standard MPI ***
/*The entire household is considered deprived if any school-aged 
child is not attending school up to class 8. */ 
******************************************************************* 

gen	child_schoolage = (age>=6 & age<=14)
	//In Cambodia, the official school entrance age is 6 years.  
	//So, age range is 6-14 (=6+8)  

	
	/*A control variable is created on whether there is no information on 
	school attendance for at least 2/3 of the school age children */
count if child_schoolage==1 & attendance==.
	//Understand how many eligible school aged children are not attending school 
gen temp = 1 if child_schoolage==1 & attendance!=.
	/*Generate a variable that captures the number of eligible school aged 
	children who are attending school */
bysort hh_id: egen no_missing_atten = sum(temp)	
	/*Total school age children with no missing information on school 
	attendance */
gen temp2 = 1 if child_schoolage==1	
bysort hh_id: egen hhs = sum(temp2)
	//Total number of household members who are of school age
replace no_missing_atten = no_missing_atten/hhs 
replace no_missing_atten = (no_missing_atten>=2/3)
	/*Identify whether there is missing information on school attendance for 
	more than 2/3 of the school age children */			
tab no_missing_atten, miss
	//Check that values for 0 are less than 1%
label var no_missing_atten "No missing school attendance for at least 2/3 of the school aged children"		
drop temp temp2 hhs
	
	
bysort hh_id: egen hh_children_schoolage = sum(child_schoolage)
replace hh_children_schoolage = (hh_children_schoolage>0) 
	//Control variable: 
	//It takes value 1 if the household has children in school age
lab var hh_children_schoolage "Household has children in school age"


gen	child_not_atten = (attendance==0) if child_schoolage==1
replace child_not_atten = . if attendance==. & child_schoolage==1
bysort	hh_id: egen any_child_not_atten = max(child_not_atten)
gen	hh_child_atten = (any_child_not_atten==0) 
replace hh_child_atten = . if any_child_not_atten==.
replace hh_child_atten = 1 if hh_children_schoolage==0
replace hh_child_atten = . if hh_child_atten==1 & no_missing_atten==0 
lab var hh_child_atten "Household has all school age children up to class 8 in school"
tab hh_child_atten, miss

	
*** Destitution MPI ***
/*The entire household is considered deprived if any school-aged 
child is not attending school up to class 6. */ 
******************************************************************* 
gen	child_schoolage_6 = (age>=6 & age<=12) 
	//Note: In Cambodia, the official school entrance age is 6 years.  
	//So, age range for destitution measure is 6-12 (=6+6) 

	
	/*A control variable is created on whether there is no information on 
	school attendance for at least 2/3 of the children attending school up to 
	class 6 */	
count if child_schoolage_6==1 & attendance==.
	//Understand how many eligible school aged children are not attending school 	
gen temp = 1 if child_schoolage_6==1 & attendance!=.
	/*Generate a variable that captures the number of eligible school aged 
	children who are attending school */
bysort hh_id: egen no_missing_atten_u = sum(temp)	
	/*Total school age children attending up to class 6 with no missing 
	information on school attendance */
gen temp2 = 1 if child_schoolage_6==1	
bysort hh_id: egen hhs = sum(temp2)
	/*Total number of household members who are of school age attending up to 
	class 6 */
replace no_missing_atten_u = no_missing_atten_u/hhs 
replace no_missing_atten_u = (no_missing_atten_u>=2/3)
	/*Identify whether there is missing information on school attendance for 
	more than 2/3 of the school age children attending up to class 6 */			
tab no_missing_atten_u, miss
	//Check that values for 0 are less than 1% (0%)
label var no_missing_atten_u "No missing school attendance for at least 2/3 of the school aged children"		
drop temp temp2 hhs		
	
	
bysort	hh_id: egen hh_children_schoolage_6 = sum(child_schoolage_6)
replace hh_children_schoolage_6 = (hh_children_schoolage_6>0) 
lab var hh_children_schoolage_6 "Household has children in school age (6 years of school)"

gen	child_atten_6 = (attendance==1) if child_schoolage_6==1
replace child_atten_6 = . if attendance==. & child_schoolage_6==1
bysort	hh_id: egen any_child_atten_6 = max(child_atten_6)
gen	hh_child_atten_u = (any_child_atten_6==1) 
replace hh_child_atten_u = . if any_child_atten_6==.
replace hh_child_atten_u = 1 if hh_children_schoolage_6==0
replace hh_child_atten_u = . if hh_child_atten_u==0 & no_missing_atten_u==0 
lab var hh_child_atten_u "Household has at least one school age children up to class 6 in school"
tab hh_child_atten_u, miss
// 3.96% 0, all others 1

********************************************************************************
*** Step 2.3 Nutrition ***
********************************************************************************

********************************************************************************
*** Step 2.3a Adult Nutrition ***
********************************************************************************

lookfor body mass
codebook ha40 
	/*Check that information in ha40 and hb40 is not all missing. If hb40 is 
	not present in the dataset, please remove hb40 */
// ha40 BMI values ranges from 1217 to 5946 (there are also 6 9998 ["flagged cases"] and 601 9999)

foreach var in ha40 {
			 gen inf_`var' = 1 if `var'!=.
			 bysort sex: tab age inf_`var' 
			 /* Check whether the sample covered is restricted to the 
			 reproductive age group. If the age deviates from the usual 
			 reproductive age gorup, then please note down the age group that 
			 is covered for women and for men. 
			 
			 Cambodia DHS 2010 has anthropometric data only for women 
			 15-49 years
			 */
			 drop inf_`var'
			 }
***

*** BMI Indicator for Women 15-49 years ***
******************************************************************* 
gen	f_bmi = ha40/100
lab var f_bmi "Women's BMI"
gen	f_low_bmi = (f_bmi<18.5)
replace f_low_bmi = . if f_bmi==. | f_bmi>=99.97
lab var f_low_bmi "BMI of women < 18.5"

gen	f_low_bmi_u = (f_bmi<17)
replace f_low_bmi_u = . if f_bmi==. | f_bmi>=99.97
lab var f_low_bmi_u "BMI of women <17"
	//Note: The BMI threshold applied for destitution is 17 instead of 18.5


*** BMI Indicator for Men 15-49 years ***
******************************************************************* 
	//Note: Cambodia DHS 2010 has no anthropometric data for men. 
	
gen m_bmi = .
lab var m_bmi "Male's BMI"
gen m_low_bmi = .
lab var m_low_bmi "BMI of male < 18.5"

gen m_low_bmi_u = .
lab var m_low_bmi_u "BMI of male <17"


*** Standard MPI: BMI-for-age for individuals 15-19 years 
*** 				  and BMI for individuals 20-49 years ***
*******************************************************************  
gen low_bmi_byage = 0
lab var low_bmi_byage "Individuals with low BMI or BMI-for-age"
replace low_bmi_byage = 1 if f_low_bmi==1
	//Replace variable "low_bmi_byage = 1" if eligible women have low BMI	
replace low_bmi_byage = 1 if low_bmi_byage==0 & m_low_bmi==1 
	/*Replace variable "low_bmi_byage = 1" if eligible men have low BMI. If 
	there is no male anthropometric data, then 0 changes are made.*/

	
/*Note: The following command replaces BMI with BMI-for-age for those between 
the age group of 15-19 by their age in months where information is available */
	//Replacement for girls: 
replace low_bmi_byage = 1 if low_bmiage==1 & age_month!=.
replace low_bmi_byage = 0 if low_bmiage==0 & age_month!=.
	/*Replacements for boys - if there is no male anthropometric data for boys, 
	then 0 changes are made: */
replace low_bmi_byage = 1 if low_bmiage_b==1 & age_month_b!=.
replace low_bmi_byage = 0 if low_bmiage_b==0 & age_month_b!=.
	
	
/*Note: The following control variable is applied when there is BMI information 
for adults and BMI-for-age for teenagers.*/	
replace low_bmi_byage = . if f_low_bmi==. & m_low_bmi==. & low_bmiage==. & low_bmiage_b==. 
		
bysort hh_id: egen low_bmi = max(low_bmi_byage)
gen	hh_no_low_bmiage = (low_bmi==0)
	/*Households take a value of '1' if all eligible adults and teenagers in the 
	household has normal bmi or bmi-for-age */	
replace hh_no_low_bmiage = . if low_bmi==.
	/*Households take a value of '.' if there is no information from eligible 
	individuals in the household */
replace hh_no_low_bmiage = 1 if no_adults_eligible==1	
	//Households take a value of '1' if there is no eligible adult population.
drop low_bmi
lab var hh_no_low_bmiage "Household has no adult with low BMI or BMI-for-age"
tab hh_no_low_bmiage, miss	

	/*NOTE that hh_no_low_bmiage takes value 1 if: (a) no any eligible 
	individuals in the household has (observed) low BMI or (b) there are no 
	eligible individuals in the household. The variable takes values 0 for 
	those households that have at least one adult with observed low BMI. 
	The variable has a missing value only when there is missing info on BMI 
	for ALL eligible adults in the household */

	
*** Destitution MPI: BMI-for-age for individuals 15-19 years 
*** 			     and BMI for individuals 20-49 years ***
********************************************************************************
gen low_bmi_byage_u = 0
replace low_bmi_byage_u = 1 if f_low_bmi_u==1
	/*Replace variable "low_bmi_byage_u = 1" if eligible women have low 
	BMI (destitute cutoff)*/	
replace low_bmi_byage_u = 1 if low_bmi_byage_u==0 & m_low_bmi_u==1 
	/*Replace variable "low_bmi_byage_u = 1" if eligible men have low 
	BMI (destitute cutoff). If there is no male anthropometric data, then 0 
	changes are made.*/

	
/*Note: The following command replaces BMI with BMI-for-age for those between 
the age group of 15-19 by their age in months where information is available */
	//Replacement for girls: 
replace low_bmi_byage_u = 1 if low_bmiage_u==1 & age_month!=.
replace low_bmi_byage_u = 0 if low_bmiage_u==0 & age_month!=.
	/*Replacements for boys - if there is no male anthropometric data for boys, 
	then 0 changes are made: */
replace low_bmi_byage_u = 1 if low_bmiage_b_u==1 & age_month_b!=.
replace low_bmi_byage_u = 0 if low_bmiage_b_u==0 & age_month_b!=.
	
	
/*Note: The following control variable is applied when there is BMI information 
for adults and BMI-for-age for teenagers. */
replace low_bmi_byage_u = . if f_low_bmi_u==. & low_bmiage_u==. & m_low_bmi_u==. & low_bmiage_b_u==. 

		
bysort hh_id: egen low_bmi = max(low_bmi_byage_u)
gen	hh_no_low_bmiage_u = (low_bmi==0)
	/*Households take a value of '1' if all eligible adults and teenagers in the 
	household has normal bmi or bmi-for-age (destitution cutoff) */
replace hh_no_low_bmiage_u = . if low_bmi==.
	/*Households take a value of '.' if there is no information from eligible 
	individuals in the household */
replace hh_no_low_bmiage_u = 1 if no_adults_eligible==1	
	//Households take a value of '1' if there is no eligible adult population.
drop low_bmi
lab var hh_no_low_bmiage_u "Household has no adult with low BMI or BMI-for-age(<17/-3sd)"
tab hh_no_low_bmiage_u, miss	


********************************************************************************
*** Step 2.3b Child Nutrition ***
********************************************************************************

*** Child Underweight Indicator ***
************************************************************************

*** Standard MPI ***
bysort hh_id: egen temp = max(underweight)
gen	hh_no_underweight = (temp==0) 
	//Takes value 1 if no child in the hh is underweight 
replace hh_no_underweight = . if temp==.
replace hh_no_underweight = 1 if no_child_eligible==1 
	//Households with no eligible children will receive a value of 1
lab var hh_no_underweight "Household has no child underweight - 2 stdev"
drop temp


*** Destitution MPI  ***
bysort hh_id: egen temp = max(underweight_u)
gen	hh_no_underweight_u = (temp==0) 
replace hh_no_underweight_u = . if temp==.
replace hh_no_underweight_u = 1 if no_child_eligible==1 
lab var hh_no_underweight_u "Destitute: Household has no child underweight"
drop temp


*** Child Stunting Indicator ***
************************************************************************

*** Standard MPI ***
bysort hh_id: egen temp = max(stunting)
gen	hh_no_stunting = (temp==0) 
	//Takes value 1 if no child in the hh is stunted
replace hh_no_stunting = . if temp==.
replace hh_no_stunting = 1 if no_child_eligible==1 
	//Households with no eligible children will receive a value of 1
lab var hh_no_stunting "Household has no child stunted - 2 stdev"
drop temp


*** Destitution MPI  ***
bysort hh_id: egen temp = max(stunting_u)
gen	hh_no_stunting_u = (temp==0) 
replace hh_no_stunting_u = . if temp==.
replace hh_no_stunting_u = 1 if no_child_eligible==1 
lab var hh_no_stunting_u "Destitute: Household has no child stunted"
drop temp


*** Child Wasting Indicator ***
************************************************************************

*** Standard MPI ***
bysort hh_id: egen temp = max(wasting)
gen	hh_no_wasting = (temp==0) 
	//Takes value 1 if no child in the hh is wasted
replace hh_no_wasting = . if temp==.
replace hh_no_wasting = 1 if no_child_eligible==1 
	//Households with no eligible children will receive a value of 1
lab var hh_no_wasting "Household has no child wasted - 2 stdev"
drop temp


*** Destitution MPI  ***
bysort hh_id: egen temp = max(wasting_u)
gen	hh_no_wasting_u = (temp==0) 
replace hh_no_wasting_u = . if temp==.
replace hh_no_wasting_u = 1 if no_child_eligible==1 
lab var hh_no_wasting_u "Destitute: Household has no child wasted"
drop temp


*** Child Either Underweight or Stunted Indicator ***
************************************************************************

*** Standard MPI ***
gen hh_no_uw_st = 1 if hh_no_stunting==1 & hh_no_underweight==1
replace hh_no_uw_st = 0 if hh_no_stunting==0 | hh_no_underweight==0
	//Takes value 0 if child in the hh is stunted or underweight 
replace hh_no_uw_st = . if hh_no_stunting==. & hh_no_underweight==.
replace hh_no_uw_st = 1 if no_child_eligible==1
	//Households with no eligible children will receive a value of 1 
lab var hh_no_uw_st "Household has no child underweight or stunted"


*** Destitution MPI  ***
gen hh_no_uw_st_u = 1 if hh_no_stunting_u==1 & hh_no_underweight_u==1
replace hh_no_uw_st_u = 0 if hh_no_stunting_u==0 | hh_no_underweight_u==0
replace hh_no_uw_st_u = . if hh_no_stunting_u==. & hh_no_underweight_u==.
replace hh_no_uw_st_u = 1 if no_child_eligible==1 
lab var hh_no_uw_st_u "Destitute: Household has no child underweight or stunted"


********************************************************************************
*** Step 2.3c Household Nutrition Indicator ***
********************************************************************************

*** Standard MPI ***
/* Members of the household are considered deprived if the household has a 
child under 5 whose height-for-age or weight-for-age is under two standard 
deviation below the median, or has teenager with BMI-for-age that is under two 
standard deviation below the median, or has adults with BMI threshold that is 
below 18.5 kg/m2. Households that have no eligible adult AND no eligible 
children are considered non-deprived. The indicator takes a value of missing 
only if all eligible adults and eligible children have missing information 
in their respective nutrition variable. */
************************************************************************
gen	hh_nutrition_uw_st = 1
replace hh_nutrition_uw_st = 0 if hh_no_low_bmiage==0 | hh_no_uw_st==0
replace hh_nutrition_uw_st = . if hh_no_low_bmiage==. & hh_no_uw_st==.
	/*Replace indicator as missing if household has eligible adult and child 
	with missing nutrition information */
replace hh_nutrition_uw_st = . if hh_no_low_bmiage==. & hh_no_uw_st==1 & no_child_eligible==1
	/*Replace indicator as missing if household has eligible adult with missing 
	nutrition information and no eligible child for anthropometric measures */ 
replace hh_nutrition_uw_st = . if hh_no_uw_st==. & hh_no_low_bmiage==1 & no_adults_eligible==1
	/*Replace indicator as missing if household has eligible child with missing 
	nutrition information and no eligible adult for anthropometric measures */ 
replace hh_nutrition_uw_st = 1 if no_eligibles==1  
 	/*We replace households that do not have the applicable population, that is, 
	women 15-49 & children 0-5, as non-deprived in nutrition*/	
lab var hh_nutrition_uw_st "Household has no individuals malnourished"
tab hh_nutrition_uw_st, miss


*** Destitution MPI ***
/* Members of the household are considered deprived if the household has a 
child under 5 whose height-for-age or weight-for-age is under three standard 
deviation below the median, or has teenager with BMI-for-age that is under three 
standard deviation below the median, or has adults with BMI threshold that is 
below 17.0 kg/m2. Households that have no eligible adult AND no eligible 
children are considered non-deprived. The indicator takes a value of missing 
only if all eligible adults and eligible children have missing information 
in their respective nutrition variable. */
************************************************************************
gen	hh_nutrition_uw_st_u = 1
replace hh_nutrition_uw_st_u = 0 if hh_no_low_bmiage_u==0 | hh_no_uw_st_u==0
replace hh_nutrition_uw_st_u = . if hh_no_low_bmiage_u==. & hh_no_uw_st_u==.
	/*Replace indicator as missing if household has eligible adult and child 
	with missing nutrition information */
replace hh_nutrition_uw_st_u = . if hh_no_low_bmiage_u==. & hh_no_uw_st_u==1 & no_child_eligible==1
	/*Replace indicator as missing if household has eligible adult with missing 
	nutrition information and no eligible child for anthropometric measures */ 
replace hh_nutrition_uw_st_u = . if hh_no_uw_st_u==. & hh_no_low_bmiage_u==1 & no_adults_eligible==1
	/*Replace indicator as missing if household has eligible child with missing 
	nutrition information and no eligible adult for anthropometric measures */ 
replace hh_nutrition_uw_st_u = 1 if no_eligibles==1   
 	/*We replace households that do not have the applicable population, that is, 
	women 15-49 & children 0-5, as non-deprived in nutrition*/ 	
lab var hh_nutrition_uw_st_u "Household has no individuals malnourished (destitution)"
tab hh_nutrition_uw_st_u, miss


********************************************************************************
*** Step 2.4 Child Mortality ***
********************************************************************************
	
codebook v206 v207 mv206 mv207  // mv206 mv207 are empty in 2014, but are available here and in 2005


	//Total child mortality reported by eligible women
egen temp_f = rowtotal(v206 v207), missing
replace temp_f = 0 if v201==0
	//This line replaces women who have never given birth has 0.
bysort	hh_id: egen child_mortality_f = sum(temp_f), missing
lab var child_mortality_f "Occurrence of child mortality reported by women"
tab child_mortality_f, miss
drop temp_f
	
	//Total child mortality reported by eligible men	
egen temp_m = rowtotal(mv206 mv207), missing
replace temp_m = 0 if mv201==0
bysort	hh_id: egen child_mortality_m = sum(temp_m), missing
lab var child_mortality_m "Occurrence of child mortality reported by men"
tab child_mortality_m, miss
drop temp_m

// Harmonization: Exclude child mortality reported by men. Replace the following chunk of code with the one below it. Child mortality reported by men is available in 2005 and 2010, but not in 2014. To harmonize the child mortality indicator across the three years, child mortality reported by men is excluded from 2005 and 2010 indicators.

/*
egen child_mortality = rowmax(child_mortality_f child_mortality_m)
lab var child_mortality "Total child mortality within household reported by women & men"
tab child_mortality, miss	
*/

clonevar child_mortality = child_mortality_f
lab var child_mortality "Total child mortality within household reported by women"
tab child_mortality, miss
compare child_mortality child_mortality_f

*** Standard MPI *** 
/* Members of the household are considered deprived if women in the household 
reported mortality among children under 18 in the last 5 years from the survey 
year. Members of the household is considered non-deprived if eligible women 
within the household reported (i) no child mortality or (ii) if any child died 
longer than 5 years from the survey year or (iii) if any child 18 years and 
older died in the last 5 years. In adddition, members of the household were 
identified as non-deprived if eligible men within the household reported no 
child mortality in the absence of information from women. Households that have 
no eligible women or adult are considered non-deprived. The indicator takes 
a missing value if there was missing information on reported death from 
eligible individuals. */
************************************************************************

tab childu18_died_per_wom_5y, miss
	/* The 'childu18_died_per_wom_5y' variable was constructed in Step 1.2 using 
	information from individual women who ever gave birth in the BR file. The 
	missing values represent eligible woman who have never ever given birth and 
	so are not present in the BR file. But these 'missing women' may be living 
	in households where there are other women with child mortality information 
	from the BR file. So at this stage, it is important that we aggregate the 
	information that was obtained from the BR file at the household level. This
	ensures that women who were not present in the BR file is assigned with a 
	value, following the information provided by other women in the household.*/
replace childu18_died_per_wom_5y = 0 if v201==0 
	/*Assign a value of "0" for:
	- all eligible women who never ever gave birth */	
replace childu18_died_per_wom_5y = 0 if no_fem_eligible==1 
	/*Assign a value of "0" for:
	- individuals living in households that have non-eligible women */		
bysort hh_id: egen childu18_mortality_5y = sum(childu18_died_per_wom_5y), missing
replace childu18_mortality_5y = 0 if childu18_mortality_5y==. & child_mortality==0
	/*Replace all households as 0 death if women has missing value and men 
	reported no death in those households */
	/*After harmonization, the line makes no change. 
	Before harmonization, the line replaces all households as 0 death if women has missing value and men 
	reported no death in those households */
label var childu18_mortality_5y "Under 18 child mortality within household past 5 years reported by women"
tab childu18_mortality_5y, miss		
	
gen hh_mortality_u18_5y = (childu18_mortality_5y==0)
replace hh_mortality_u18_5y = . if childu18_mortality_5y==.
lab var hh_mortality_u18_5y "Household had no under 18 child mortality in the last 5 years"
tab hh_mortality_u18_5y, miss 


*** Destitution MPI *** 
*** (same as standard MPI) ***
************************************************************************
gen hh_mortality_u = hh_mortality_u18_5y	
lab var hh_mortality_u "Household had no under 18 child mortality in the last 5 years"	


********************************************************************************
*** Step 2.5 Electricity ***
********************************************************************************

*** Standard MPI ***
****************************************

clonevar electricity = hv206 
codebook electricity, tab (10)
// no, yes, 9
replace electricity = . if electricity==9 
	//Please check that missing values remain missing
label var electricity "Household has electricity"


*** Destitution MPI  ***
*** (same as standard MPI) ***
****************************************

gen electricity_u = electricity
label var electricity_u "Household has electricity"


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

clonevar toilet = hv205  
	//Save the original variable
codebook toilet, tab(100) 
	//Check coding
	// 2010 questionnaire is the same as 2014; In this dataset, 11-43 all labeled the same as 2014; 96 & 99 not found in 2014 dataset but are present here
codebook hv225, tab(30)  
	//Check coding for shared toilet
clonevar shared_toilet = hv225 
	//Check coding: 0=no;1=yes;.=missing

	
*** Standard MPI ***
/*Members of the household are considered deprived if the household's 
sanitation facility is not improved (according to the SDG guideline) 
or it is improved but shared with other households*/
********************************************************************

	/*Note: Cambodia DHS 2010-11, improved toilet facilities include flush to
	  piped sewer system, flush to septic tank, flush to pit latrine, VIP latrine,
	  pit latrine with slab, and composting toilet.
	  
	  Non-improved toilet facilities include any facility shared with other 
	  households, flush not to sewer/septic tank/pit latrine, pit latrine without 
	  slab, bucket, hanging toilet, no facility, other, and missing. (p.19)*/

gen	toilet_mdg = ((toilet<23 | toilet==41) & shared_toilet!=1) 
	/*Household is assigned a value of '1' if it uses improved sanitation and 
	does not share toilet with other households  */
	
replace toilet_mdg = 0 if (toilet<23 | toilet==41)  & shared_toilet==1   
	/*Household is assigned a value of '0' if it uses improved sanitation 
	but shares toilet with other households  */	
	
replace toilet_mdg = 0 if toilet == 14 | toilet == 15 | toilet==99 
	/*Household is assigned a value of '0' if it uses non-improved sanitation: 
	"flush to somewhere else" and "flush don't know where"  */	
	// also if it's toilet facility type information is coded as 99

replace toilet_mdg = . if toilet==.  
	//Household is assigned a value of '.' if it has missing information 	
	
lab var toilet_mdg "Household has improved sanitation with MDG Standards"
tab toilet toilet_mdg, miss


*** Destitution MPI ***
/*Members of the household are considered deprived if household practises 
open defecation or uses other unidentifiable sanitation practises */
********************************************************************

gen	toilet_u = .

replace toilet_u = 0 if toilet==31 | toilet==96 
	/*Household is assigned a value of '0' if it practises open defecation or 
	others */
	
replace toilet_u = 1 if toilet!=31 & toilet!=96 & toilet!=. & toilet!=99
	/*Household is assigned a value of '1' if it does not practise open 
	defecation or others  */
	
lab var toilet_u "Household does not practise open defecation or others"
tab toilet toilet_u, miss


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


	/* Note: Cambodia DHS 2010-11 has no observation for hv201 (source of drinking 
	water). This is because, data on drinking water is collected for the dry and 
	wet season. The sh102 variable captures the source of drinking water during 
	the dry season and the sh104b variable captures the  source of drinking 
	water during wet season. Similarly, there is no observation for hv204 
	(time it takes to get the water). However, data on time to water is 
	available for the dry season (sh104) and wet season (sh104d). A number of the
	households use different source of water between the dry and wet 
	season. As such we construct the drinking water variable using both 
	information. Household is identified as deprived if they had used 
	non-improved source of drinking water in either dry or wet season, as well 
	as walked more than 30 minutes in either season */
/* 2010 vs 2014: the questionnaires are the same
*/
clonevar water = hv201 
clonevar water_dry = sh102
clonevar water_wet = sh104b

clonevar timetowater = hv204 
clonevar timetowater_dry = sh104  
clonevar timetowater_wet = sh104d

codebook water  // all missing
codebook water_dry, tab(30)  // same labels as 2014 except that 99 found here is encoded as . 2014 data
codebook water_wet, tab(30)  // same comment as water_dry

tab water_dry water_wet, m

codebook timetowater*, tab (9999)
  // same labels as 2014 (996: on premises; 998: don't know) except that 999 found here is encoded as . 2014 data
  
clonevar ndwater = hv202  
	//Cambodia DHS 2010-11 has no observation for non-drinking water. 
	

*** Standard MPI ***
/* Members of the household are considered deprived if the household 
does not have access to improved drinking water (according to the SDG 
guideline) or safe drinking water is at least a 30-minute walk from 
home, roundtrip */
********************************************************************

gen	water_mdg = 1 if water_dry==11 | water_dry==12 | water_dry==13 | ///
					 water_dry==21 | water_dry==31 | ///
					 water_dry==51 | water_dry==71 | ///
					 water_wet==11 | water_wet==12 | water_wet==13 | ///
					 water_wet==21 | water_wet==31 | ///
					 water_wet==51 | water_wet==71 		

/* Protected spring (41) is considered non-improved for harmonization purpose. */

replace water_mdg = 0 if water_dry==32 | water_dry==41 | water_dry==42 | water_dry==43 | ///
						 water_dry==61 | water_dry==62 | water_dry==96 | ///
						 water_wet==32 | water_wet==41 | water_wet==42 | water_wet==43 | ///
						 water_wet==61 | water_wet==62 | water_wet==96 				 
						 
tab timetowater_dry, nol
tab timetowater_wet, nol	
replace water_mdg = 0 if (water_mdg==1 & timetowater_dry >= 30 ///
						  & timetowater_dry!=. ///
						  & timetowater_dry!=996 ///
						  & timetowater_dry!=998 ///
						  & timetowater_dry!=999) ///
						  | (water_mdg==1 & timetowater_wet >= 30 ///
						  & timetowater_wet!=. ///
						  & timetowater_wet!=996 ///
						  & timetowater_wet!=998 ///
						  & timetowater_wet!=999)

						  
replace water_mdg = . if water_dry==. & water_wet==.  // water_dry and water_wet have 99, but not .
replace water_mdg = . if water_dry==99 & water_wet==99

lab var water_mdg "Household has drinking water with MDG standards (considering distance)"
tab water_wet water_mdg, miss
tab water_dry water_mdg, miss
tab water_mdg, miss  // 45.18% deprived


*** Destitution MPI ***
/* Members of the household is identified as destitute if household 
does not have access to safe drinking water, or safe water is more 
than 45 minute walk from home, round trip.*/
********************************************************************
gen	water_u = 1 if   water_dry==11 | water_dry==12 | water_dry==13 | ///
					 water_dry==21 | water_dry==31 | water_dry==41 | ///
					 water_dry==51 | water_dry==71 | ///
					 water_wet==11 | water_wet==12 | water_wet==13 | ///
					 water_wet==21 | water_wet==31 | water_wet==41 | ///
					 water_wet==51 | water_wet==71 		
	
replace water_u = 0 if   water_dry==32 | water_dry==42 | water_dry==43 | ///
						 water_dry==61 | water_dry==62 | water_dry==96 | ///
						 water_wet==32 | water_wet==42 | water_wet==43 | ///
						 water_wet==61 | water_wet==62 | water_wet==96 				 

						
replace water_u = 0 if   (water_u==1 & timetowater_dry > 45 ///
						  & timetowater_dry!=. ///
						  & timetowater_dry!=996 ///
						  & timetowater_dry!=998 ///
						  & timetowater_dry!=999) ///
						  | (water_u==1 & timetowater_wet > 45 ///
						  & timetowater_wet!=. ///
						  & timetowater_wet!=996 ///
						  & timetowater_wet!=998 ///
						  & timetowater_wet!=999)

replace water_u = . if water_dry==. & water_wet==. 
replace water_u = . if water_dry==99 & water_wet==99
	
lab var water_u "Household has drinking water with MDG standards (45 minutes distance)"
tab water_u, miss


********************************************************************************
*** Step 2.8 Housing ***
********************************************************************************
// 2010 & 2014 share the same questionnaires for floor, wall, and roof materials

/* Members of the household are considered deprived if the household 
has a dirt, sand or dung floor */
clonevar floor = hv213 
codebook floor, tab(100)
// same labels as 2014 except 1) 12: dung found in 2014, but not here, 2) for code > 41, 96: other found here, but only . in 2014
gen	floor_imp = 1
replace floor_imp = 0 if floor==11 | floor==96  
replace floor_imp = . if floor==. | floor==99 
lab var floor_imp "Household has floor that it is not earth/sand/dung"
tab floor floor_imp, miss		


/* Members of the household are considered deprived if the household has walls 
made of natural or rudimentary materials. Please follow the report's definitions
of natural or rudimentary materials. */
/* Harmonization: also deprived if covered adobe (wall==35). Covered adobe is available as an option of wall material in 2010 and 2014, but not 2005. Households with covered adobe walls in 2005 might have been classified as having "other" wall materials (wall==96, which is considered unimproved). To harmonize the housing indicator across the three years, covered adobe is considered an unimproved wall material in 2010 and 2014.*/
clonevar wall = hv214 
codebook wall, tab(100)	
// same labels as 2014 except 1) 23: stone with mud found here, but not 2014, 2) 99 found here, but encoded as . in 2014 data
gen	wall_imp = 1 
replace wall_imp = 0 if wall<=28 | wall==35 | wall==96  	
replace wall_imp = . if wall==. | wall==99 	
lab var wall_imp "Household has wall that it is not of low quality materials"
tab wall wall_imp, miss	
	
	
/* Members of the household are considered deprived if the household has roof 
made of natural or rudimentary materials */
/* Harmonization: also deprived if wood (roof==32). Wood is available as an option of roof material in 2010 and 2014, but not 2005. Households with wood roofs in 2005 might have been classified as having "other" roof materials (roof==96, which is considered unimproved). To harmonize the housing indicator across the three years, wood is considered an unimproved roof material in 2010 and 2014.*/
clonevar roof = hv215
codebook roof, tab(100)	
// same labels as 2014 except 1) 24: plastic sheet found in 2014, but not here, 2) for codes > 39, 96 and 99 found here but only . found in 2014
gen	roof_imp = 1 
replace roof_imp = 0 if roof<=23 | roof==32 | roof==96  	
replace roof_imp = . if roof==. | roof==99 	
lab var roof_imp "Household has roof that it is not of low quality materials"
tab roof roof_imp, miss


*** Standard MPI ***
/* Members of the household is deprived in housing if the roof, 
floor OR walls are constructed from low quality materials.*/
**************************************************************
gen housing_1 = 1
replace housing_1 = 0 if floor_imp==0 | wall_imp==0 | roof_imp==0
replace housing_1 = . if floor_imp==. & wall_imp==. & roof_imp==.
lab var housing_1 "Household has roof, floor & walls that it is not low quality material"
tab housing_1, miss


*** Standard MPI Customized ***
/* Members of the household is deprived in housing if the roof OR floor are constructed from low quality materials.*/
**************************************************************
gen housing_no_wall = 1
replace housing_no_wall = 0 if floor_imp==0 | roof_imp==0
replace housing_no_wall = . if floor_imp==. & roof_imp==.
lab var housing_no_wall "Household has roof & floor that it is not low quality material"
tab housing_no_wall, miss


*** Destitution MPI ***
/* Members of the household is deprived in housing if two out 
of three components (roof and walls; OR floor and walls; OR 
roof and floor) the are constructed from low quality materials. */
**************************************************************
gen housing_u = 1
replace housing_u = 0 if (floor_imp==0 & wall_imp==0 & roof_imp==1) | ///
						 (floor_imp==0 & wall_imp==1 & roof_imp==0) | ///
						 (floor_imp==1 & wall_imp==0 & roof_imp==0) | ///
						 (floor_imp==0 & wall_imp==0 & roof_imp==0)
replace housing_u = . if floor_imp==. & wall_imp==. & roof_imp==.
lab var housing_u "Household has one of three aspects(either roof,floor/walls) that is not low quality material"
tab housing_u, miss



********************************************************************************
*** Step 2.9 Cooking Fuel ***
********************************************************************************

/*
Solid fuel are solid materials burned as fuels, which includes coal as well as 
solid biomass fuels (wood, animal dung, crop wastes and charcoal). 

Source: 
https://apps.who.int/iris/bitstream/handle/10665/141496/9789241548885_eng.pdf
*/

clonevar cookingfuel = hv226  
// 2010 & 2014 share the same questionnaire for cooking fuel
// same labels as 2014 except 1) 9: straw/shrubs/grass & 10: agricultural crop found in 2014 but not here, 2) for codes > 95, 96: other found here, but only . in 2014

*** Standard MPI ***
/* Members of the household are considered deprived if the 
household uses solid fuels and solid biomass fuels for cooking. */
*****************************************************************
codebook cookingfuel, tab(99)
gen	cooking_mdg = 1  // 96: other is considered non-deprived
replace cooking_mdg = 0 if cookingfuel>5 & cookingfuel<95 
replace cooking_mdg = . if cookingfuel==. | cookingfuel==99
lab var cooking_mdg "Household has cooking fuel by MDG standards"		 
tab cookingfuel cooking_mdg, miss	


*** Destitution MPI ***
*** (same as standard MPI) ***
****************************************
gen	cooking_u = cooking_mdg
lab var cooking_u "Household uses clean fuels for cooking"


********************************************************************************
*** Step 2.10 Assets ownership ***
********************************************************************************


*** Television/LCD TV/plasma TV/color TV/black & white tv
lookfor tv television plasma lcd	
codebook hv208
clonevar television = hv208 
// 2010 & 2014 have same question in questionnaire
lab var television "Household has television"	


***	Radio/walkman/stereo/kindle
lookfor radio walkman stereo
codebook hv207
clonevar radio = hv207 
// 2010 & 2014 have same question in questionnaire
lab var radio "Household has radio"	

	
***	Handphone/telephone/iphone/mobilephone/ipod
// 2010 & 2014 have same question in questionnaire
lookfor telephone mobilephone ipod
codebook hv221 hv243a
clonevar telephone = hv221
clonevar landline = hv221
clonevar mobiletelephone = hv243a

// Harmonization: Exclude non-mobile telephone (landline). Replace the following chunk of code with the one below it. Landline is available in 2010 and 2014, but not 2005. To harmonize the asset indicator across the three years, landline is excluded from 2010 and 2014 indicators.

/*
replace telephone=1 if telephone!=1 & hv243a==1	
	//hv243a=mobilephone. Combine information on telephone and mobilephone: variable is 1 if has either telephone or mobilephone
// 2014 script does the combination in 2 lines, but the same results are achieved, so the inconsistency is ok
tab hv243a hv221 if telephone==1,miss
lab var telephone "Household has telephone (landline/mobilephone)"	
*/

replace telephone = mobiletelephone
lab var telephone "Household has mobilephone"	
	
***	Refrigerator/icebox/fridge
lookfor refrigerator 
codebook hv209
clonevar refrigerator = hv209 
// 2010 & 2014 have same question in questionnaire
lab var refrigerator "Household has refrigerator"


***	Car/van/lorry/truck
lookfor car voiture truck van
codebook hv212
clonevar car = hv212  
// 2014 questionnaire asks about ownership of "A car or truck, tractor or van?", but 2010 questionnaire asks about ownership of "A car or truck or van?"
lab var car "Household has car"	


		
***	Bicycle/cycle rickshaw
lookfor bicycle bicyclette
codebook hv210	
clonevar bicycle = hv210 
// 2010 & 2014 have same question in questionnaire
lab var bicycle "Household has bicycle"	


***	Motorbike/motorized bike/autorickshaw
lookfor motorbike moto
codebook hv211
clonevar motorbike = hv211 
// 2010 & 2014 have same question in questionnaire
lab var motorbike "Household has motorbike"	

	
***	Computer/laptop/tablet
lookfor computer ordinateur laptop ipad tablet
gen computer = .
lab var computer "Household has computer"


	
***	Animal cart
lookfor cart 
codebook hv243c
clonevar animal_cart = hv243c
// 2010 & 2014 have same question in questionnaire
lab var animal_cart "Household has animal cart"	


foreach var in television radio telephone refrigerator car ///
			   bicycle motorbike computer animal_cart {
replace `var' = . if `var'==9 | `var'==99 | `var'==8 | `var'==98 
}
	//Missing values replaced


*** Standard MPI ***
/* Members of the household are considered deprived in assets if the household 
does not own more than one of: radio, TV, telephone, bike, motorbike, 
refrigerator, computer or animal cart and does not own a car or truck.*/
*****************************************************************************
egen n_small_assets2 = rowtotal(television radio telephone refrigerator bicycle motorbike computer animal_cart), missing
lab var n_small_assets2 "Household Number of Small Assets Owned" 

// count if n_small_assets2==2 & car!=1 & landline==1 & mobiletelephone==0  // Before harmonization: 59 non-deprived would be deprived if landline variable is excluded

gen hh_assets2 = (car==1 | n_small_assets2 > 1) 
replace hh_assets2 = . if car==. & n_small_assets2==.
lab var hh_assets2 "Household Asset Ownership: HH has car or more than 1 small assets incl computer & animal cart"


*** Destitution MPI ***
/* Members of the household are considered deprived in assets if the household 
does not own any assets.*/
*****************************************************************************	
gen	hh_assets2_u = (car==1 | n_small_assets2>0)
replace hh_assets2_u = . if car==. & n_small_assets2==.
lab var hh_assets2_u "Household Asset Ownership: HH has car or at least 1 small assets incl computer & animal cart"

	
********************************************************************************
*** Step 2.11 Rename and keep variables for MPI calculation 
********************************************************************************

	//Retain DHS wealth index:
desc hv270 	
clonevar windex=hv270

desc hv271
clonevar windexf=hv271


	//Retain data on sampling design: 
desc hv022 hv021	
clonevar strata = hv022
clonevar psu = hv021
label var psu "Primary sampling unit"
label var strata "Sample strata"

compare psu hv001  // no difference

	//Retain year, month & date of interview:
desc hv007 hv006 hv008
clonevar year_interview = hv007 	
clonevar month_interview = hv006 
clonevar date_interview = hv008
 
save "$path_out/khm_dhs10_raw.dta", replace 


use "$path_out/khm_dhs10_raw.dta", clear 	
*** Rename key global MPI indicators for estimation ***
recode hh_mortality_u18_5y  (0=1)(1=0) , gen(d_cm)
recode hh_nutrition_uw_st 	(0=1)(1=0) , gen(d_nutr)
recode hh_child_atten 		(0=1)(1=0) , gen(d_satt)
recode hh_years_edu6 		(0=1)(1=0) , gen(d_educ)
recode electricity 			(0=1)(1=0) , gen(d_elct)
recode water_mdg 			(0=1)(1=0) , gen(d_wtr)
recode toilet_mdg 			(0=1)(1=0) , gen(d_sani)
recode housing_no_wall		(0=1)(1=0) , gen(d_hsg)  // housing_1 in standard MPI
recode cooking_mdg 			(0=1)(1=0) , gen(d_ckfl)
recode hh_assets2 			(0=1)(1=0) , gen(d_asst)
 
/**
Destitution MPI is not used, so the following lines are not run

*** Rename key global MPI indicators for destitution estimation ***
recode hh_mortality_u       (0=1)(1=0) , gen(dst_cm)
recode hh_nutrition_uw_st_u (0=1)(1=0) , gen(dst_nutr)
recode hh_child_atten_u 	(0=1)(1=0) , gen(dst_satt)
recode hh_years_edu_u 		(0=1)(1=0) , gen(dst_educ)
recode electricity_u		(0=1)(1=0) , gen(dst_elct)
recode water_u 				(0=1)(1=0) , gen(dst_wtr)
recode toilet_u 			(0=1)(1=0) , gen(dst_sani)
recode housing_u 			(0=1)(1=0) , gen(dst_hsg)
recode cooking_u			(0=1)(1=0) , gen(dst_ckfl)
recode hh_assets2_u 		(0=1)(1=0) , gen(dst_asst) 

**/
 
*** Rename indicators for changes over time estimation ***	
recode hh_mortality_u18_5y  (0=1)(1=0) , gen(d_cm_01)
recode hh_nutrition_uw_st 	(0=1)(1=0) , gen(d_nutr_01)
recode hh_child_atten 		(0=1)(1=0) , gen(d_satt_01)
recode hh_years_edu6 		(0=1)(1=0) , gen(d_educ_01)
recode electricity 			(0=1)(1=0) , gen(d_elct_01)
recode water_mdg 			(0=1)(1=0) , gen(d_wtr_01)
recode toilet_mdg 			(0=1)(1=0) , gen(d_sani_01)
recode housing_no_wall 		(0=1)(1=0) , gen(d_hsg_01)  // housing_1 in standard MPI
recode cooking_mdg 			(0=1)(1=0) , gen(d_ckfl_01)
recode hh_assets2 			(0=1)(1=0) , gen(d_asst_01)	
	
/**
Destitution MPI is not used, so the following lines are not run

recode hh_mortality_u       (0=1)(1=0) , gen(dst_cm_01)
recode hh_nutrition_uw_st_u (0=1)(1=0) , gen(dst_nutr_01)
recode hh_child_atten_u 	(0=1)(1=0) , gen(dst_satt_01)
recode hh_years_edu_u 		(0=1)(1=0) , gen(dst_educ_01)
recode electricity_u		(0=1)(1=0) , gen(dst_elct_01)
recode water_u	 			(0=1)(1=0) , gen(dst_wtr_01)
recode toilet_u 			(0=1)(1=0) , gen(dst_sani_01)
recode housing_u 			(0=1)(1=0) , gen(dst_hsg_01)
recode cooking_u			(0=1)(1=0) , gen(dst_ckfl_01)
recode hh_assets2_u 		(0=1)(1=0) , gen(dst_asst_01) 
**/

	/*In this survey, the harmonised 'region_01' variable is the 
	same as the standardised 'region' variable.*/	
clonevar region_01 = region  



*** Keep main variables require for MPI calculation ***
// Harmonization: headship not kept as it is not computed in 2005
keep hh_id ind_id psu strata subsample weight ///
area region region_01 agec4 agec2 ///
d_cm d_nutr d_satt d_educ d_elct d_wtr d_sani d_hsg d_ckfl d_asst /// 
d_cm_01 d_nutr_01 d_satt_01 d_educ_01 ///
d_elct_01 d_wtr_01 d_sani_01 d_hsg_01 d_ckfl_01 d_asst_01


order hh_id ind_id psu strata subsample weight ///
area region region_01 agec4 agec2 ///
d_cm d_nutr d_satt d_educ d_elct d_wtr d_sani d_hsg d_ckfl d_asst ///
d_cm_01 d_nutr_01 d_satt_01 d_educ_01 ///
d_elct_01 d_wtr_01 d_sani_01 d_hsg_01 d_ckfl_01 d_asst_01
 

*** Generate coutry and survey details for estimation ***
char _dta[cty] "Cambodia"
char _dta[ccty] "KHM"
char _dta[year] "2010" 	
char _dta[survey] "DHS"
char _dta[ccnum] "116"
char _dta[type] "micro"


*** Sort, compress and save data for estimation ***
sort ind_id
compress
la da "Micro data for `_dta[ccty]' (`_dta[ccnum]') from `c(current_date)' (`c(current_time)')."
save "$path_out/khm_dhs10.dta", replace 
