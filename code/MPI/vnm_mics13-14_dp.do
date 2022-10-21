********************************************************************************
/*
Citation:
Oxford Poverty and Human Development Initiative (OPHI), University of Oxford. 
2021 Global Multidimensional Poverty Index - Viet Nam MICS 2013-2014 
[STATA do-file]. Available from OPHI website: http://ophi.org.uk/  

For further queries, contact: ophi@qeh.ox.ac.uk
*/
********************************************************************************

clear all 
set more off
set maxvar 10000


*** Working Folder Path ***	  
global path_in "../rdta/Viet Nam MICS 2013-14" 
global path_out "cdta"
global path_ado "ado"

	
********************************************************************************
*** VIETNAM MICS 2014 ***
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

		
desc bh4c bh9c	
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
gen child18_died = child_died 
replace child18_died=0 if age_death>=216 & age_death<.
label values child18_died lab_died
tab child18_died, miss	
	
bysort ind_id: egen tot_child18_died_5y=sum(child18_died) if ydead_survey<=5
	/*Total number of children under 18 who died in the past 5 years 
	prior to the interview date */	
	
replace tot_child18_died_5y=0 if tot_child18_died_5y==. & tot_child_died>=0 & tot_child_died<.
	/*All children who are alive or who died longer than 5 years from the 
	interview date are replaced as '0'*/
	
replace tot_child18_died_5y=. if child18_died==1 & ydead_survey==.
	//Replace as '.' if there is no information on when the child died  

tab tot_child_died tot_child18_died_5y, miss

bysort ind_id: egen childu18_died_per_wom_5y = max(tot_child18_died_5y)
lab var childu18_died_per_wom_5y "Total child under 18 death for each women in the last 5 years (birth recode)"
	

	//Keep one observation per women
bysort ind_id: gen id=1 if _n==1
keep if id==1
drop id
duplicates report ind_id 


gen women_BH = 1 
	//Identification variable for observations in BH recode

	
	//Retain relevant variables
keep ind_id women_BH childu18_died_per_wom_5y 
order ind_id women_BH childu18_died_per_wom_5y
sort ind_id
save "$path_out/VNM14_BH.dta", replace	


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
keep wm7 cm1 cm8 cm9a cm9b ind_id women_WM 
order wm7 cm1 cm8 cm9a cm9b ind_id women_WM 
sort ind_id
save "$path_out/VNM14_WM.dta", replace


********************************************************************************
*** Step 1.4  MR - MEN'S RECODE  
***(All eligible man in the household) 
********************************************************************************

	//No male recode


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


save "$path_out/VNM14_HH.dta", replace


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
merge 1:1 ind_id using "$path_out/VNM14_BH.dta"
drop _merge
erase "$path_out/VNM14_BH.dta" 
 
 
*** Merging WM Recode 
*****************************************
merge 1:1 ind_id using "$path_out/VNM14_WM.dta"
drop _merge
erase "$path_out/VNM14_WM.dta"


*** Merging HH Recode 
*****************************************
merge m:1 hh_id using "$path_out/VNM14_HH.dta"
tab hh9 if _m==2
drop  if _merge==2
	//Drop households that were not interviewed 
drop _merge
erase "$path_out/VNM14_HH.dta"



sort ind_id



********************************************************************************
*** Step 1.8 CONTROL VARIABLES
********************************************************************************


*** No Eligible Women 15-49 years
*****************************************
gen	fem_eligible = (hl7>0) if hl7!=.
	//Make sure that hl7>0 does not include hl7==. 
bys	hh_id: egen hh_n_fem_eligible = sum(fem_eligible) 	
	//Number of eligible women for interview in the hh
gen	no_fem_eligible = (hh_n_fem_eligible==0) 									
	//Takes value 1 if the household had no eligible females for an interview
lab var no_fem_eligible "Household has no eligible women"
drop hh_n_fem_eligible 
tab no_fem_eligible, miss


*** No Eligible Men 
*****************************************
gen male_eligible = . 	
gen no_male_eligible = . 
lab var no_male_eligible "Household has no eligible man"

	
*** No Eligible Children 0-5 years
***************************************** 
gen	child_eligible = .	
gen	no_child_eligible = .
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
label define lab_rel 1"head" 2"spouse" 3"child" 4"extended family" ///
5"not related" 6"maid"
label values relationship lab_rel
label var relationship "Relationship to the head of household"
tab hl3 relationship, miss	


//Sex of household member
codebook hl4
clonevar sex = hl4 
label var sex "Sex of household member"


//Household headship
bys	hh_id: egen missing_hhead = min(relation)
tab missing_hhead,m 
gen household_head=.
replace household_head=1 if relation==1 & sex==1 
replace household_head=2 if relation==1 & sex==2
bysort hh_id: egen headship = sum(household_head)
replace headship = 1 if (missing_hhead==2 & sex==1)
replace headship = 2 if (missing_hhead==2 & sex==2)
replace headship = . if missing_hhead>2
label define head 1"male-headed" 2"female-headed"
label values headship head
label var headship "Household headship"
tab headship, miss


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



//Subnational region
lookfor region
codebook hh7, tab (100)
decode hh7, gen(temp)
replace temp =  proper(temp)
encode temp, gen(region)
lab var region "Region for subnational decomposition"
tab hh7 region, miss 
drop temp
label define lab_reg ///
1 "Central Highlands" ///
2 "Mekong River Delta" ///
3 "North Central & Central Coast" ///
4 "Northern Uplands" ///
5 "Red River Delta" ///
6 "Southeast"
label values region lab_reg


********************************************************************************
***  Step 2 Data preparation  ***
***  Standardization of the 10 Global MPI indicators 
***  Identification of non-deprived & deprived individuals  
********************************************************************************


********************************************************************************
*** Step 2.1 Years of Schooling ***
********************************************************************************
	/*Note: In Viet Nam, children enter primary school aged 6 years, enter lower 
	secondary school at 11 and upper secondary school at 15. There are grades in 
	primary school (Grades 1 to 5), four in lower secondary school (Grades 6 to 
	9) and three in upper secondary school (Grades 10 to 12).(pg 192 report)*/ 

tab ed4b ed4a, miss
tab age ed6a if ed5==1, miss  
clonevar edulevel = ed4a 
replace edulevel = . if ed4a>=8 
tab ed4a ed3, miss   
	//All missing values for attending school are also missing in edulevel 
replace edulevel = 0 if ed3==2 | ed3 == . 
	//Never attended school
clonevar eduhighyear = ed4b 
	//Highest grade of education completed
replace eduhighyear = .  if ed4b==. | ed4b==97 | ed4b==98 | ed4b==99   
	//These are all missing values, (97 inconsistent, 98 DK, 99 missing)  
tab ed4b ed3, miss   
	//All missing values for attending school are also missing in eduhighyear . 
replace eduhighyear = 0  if ed3==2 | ed3 == .  	
	//Never attended school
lab var eduhighyear "Highest year of education completed"
tab eduhighyear, miss


** Cleaning inconsistencies
replace eduhighyear = 0 if age<10   
	//2615 real changes made
replace eduhighyear = . if edulevel==1 & eduhighyear>5 
	//According to the report (page 192) Primary school is until 5th grade 
replace eduhighyear = . if (edulevel==2)  & eduhighyear>9   
	//Lower secondary education covers 9grades of education 
replace eduhighyear = . if (edulevel==3)  & eduhighyear>12   
	//Upper secondary education covers 12grades of education 
replace eduhighyear = 0 if edulevel==0


** Now we create the years of schooling
	//The VNM report does inform on school attainment in terms of years
gen	eduyears = eduhighyear
replace eduyears = 0 if edulevel==1 & eduhighyear==.  
	//Assuming 0 year if they only attend primary but the last year is unknown 
replace eduyears = 5 if (edulevel == 2) & (eduhighyear ==.| eduhighyear ==0) 
	//5 for primary education 
replace eduyears = 9 if (edulevel==3) & (eduhighyear ==.| eduhighyear ==0) 
replace eduyears = 12 if (edulevel==4) & (eduhighyear ==.| eduhighyear ==0) 
replace eduyears = 12 if (edulevel==4) & (eduhighyear ==.| eduhighyear ==0) 
replace eduyears = 13 if (edulevel==4 | edulevel==5) & (eduhighyear ==.| eduhighyear ==0) 
replace eduyears = 0 if edulevel == 0     
replace eduyears = . if edulevel==. 


** Checking for further inconsistencies
replace eduyears = . if age<=eduyears & age>0
replace eduyears = 0 if age<10  
lab var eduyears "Total number of years of education accomplished"


	/*A control variable is created on whether there is information on 
	years of education for at least 2/3 of the household members aged 10 years 
	and older */	
gen temp = 1 if eduyears!=. & age>=10 & age!=.
bysort	hh_id: egen no_missing_edu = sum(temp)
gen temp2 = 1 if age>=10 & age!=.
bysort hh_id: egen hhs = sum(temp2)
replace no_missing_edu = no_missing_edu/hhs
replace no_missing_edu = (no_missing_edu>=2/3)
tab no_missing_edu, miss
label var no_missing_edu "No missing edu for at least 2/3 of the HH members aged 10 years & older"	
drop temp temp2 hhs



*** Standard MPI ***
/*The entire household is considered deprived if no household member 
aged 10 years or older has completed SIX years of schooling.*/
******************************************************************* 
gen	 years_edu6 = (eduyears>=6)
replace years_edu6 = . if eduyears==.
bysort hh_id: egen hh_years_edu6_1 = max(years_edu6)
gen	hh_years_edu6 = (hh_years_edu6_1==1)
replace hh_years_edu6 = . if hh_years_edu6_1==.
replace hh_years_edu6 = . if hh_years_edu6==0 & no_missing_edu==0 
lab var hh_years_edu6 "Household has at least one member with 6 years of edu"
tab hh_years_edu6, miss

	
*** Destitution MPI ***
/*The entire household is considered deprived if no household member 
aged 10 years or older has completed at least one year of schooling.*/
******************************************************************* 
gen	years_edu1 = (eduyears>=1)
replace years_edu1 = . if eduyears==.
bysort	hh_id: egen hh_years_edu_u = max(years_edu1)
replace hh_years_edu_u = . if hh_years_edu_u==0 & no_missing_edu==0
lab var hh_years_edu_u "Household has at least one member with 1 year of edu"


********************************************************************************
*** Step 2.2 Child School Attendance ***
********************************************************************************

codebook ed5, tab (10)
gen	attendance = .
replace attendance = 1 if ed5==1 
	//Replace attendance with '1' if currently attending school
replace attendance = 0 if ed5==2 
	//Replace attendance with '0' if currently not attending school
replace attendance = 0 if ed3==2 
	//Replace attendance with '0' if never ever attended school	

tab age ed5, miss	
	//Check individuals who are not of school age
	
replace attendance = 0 if age<5 | age>24 
	//Replace attendance with '0' for individuals who are not of school age 

tab attendance, miss


*** Standard MPI ***
/*The entire household is considered deprived if any school-aged 
child is not attending school up to class 8. */ 
******************************************************************* 
gen	child_schoolage = (age>=6 & age<=14)
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
tab hh_child_atten, miss

	
*** Destitution MPI ***
/*The entire household is considered deprived if any school-aged 
child is not attending school up to class 6. */ 
*******************************************************************
gen	child_schoolage_6 = (age>=6 & age<=12) 


	/*A control variable is created on whether there is no information on 
	school attendance for at least 2/3 of the children attending school up to 
	class 6 */	
gen temp = 1 if child_schoolage_6==1 & attendance!=.
bysort hh_id: egen no_missing_atten_u = sum(temp)	
gen temp2 = 1 if child_schoolage_6==1	
bysort hh_id: egen hhs = sum(temp2)
replace no_missing_atten_u = no_missing_atten_u/hhs 
replace no_missing_atten_u = (no_missing_atten_u>=2/3)		
tab no_missing_atten_u, miss
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

gen underweight_u = .
lab var underweight_u  "Child is undernourished (weight-for-age) 3sd - WHO"

gen stunting_u=. 
lab var stunting_u "Child is stunted (length/height-for-age) 3sd - WHO"

gen wasting_u=.
lab var wasting_u  "Child is wasted (weight-for-length/height) 3sd - WHO"


gen hh_no_underweight = .
lab var hh_no_underweight "Household has no child underweight - 2 stdev"

gen hh_no_stunting  = .
lab var hh_no_stunting "Household has no child stunted - 2 stdev"

gen hh_no_wasting = .
lab var hh_no_wasting "Household has no child wasted - 2 stdev"

gen	hh_no_underweight_u = .
lab var hh_no_underweight_u "Destitute: Household has no child underweight"

gen	hh_no_stunting_u = .
lab var hh_no_stunting_u "Destitute: Household has no child stunted"

gen hh_no_wasting_u = .
lab var hh_no_wasting_u "Destitute: Household has no child wasted"

gen hh_no_uw_st = .
lab var hh_no_uw_st "Household has no child underweight or stunted"

gen hh_no_uw_st_u = .
lab var hh_no_uw_st_u "Destitute: Household has no child underweight or stunted"

gen	hh_nutrition_uw_st = .
lab var hh_nutrition_uw_st "Household has no child underweight/stunted or adult deprived by BMI/BMI-for-age"

gen	hh_nutrition_uw_st_u = .
lab var hh_nutrition_uw_st_u "Household has no child underweight/stunted or adult deprived by BMI/BMI-for-age (destitute)|"

gen weight_ch = .
label var weight_ch "sample weight child under 5"
 



********************************************************************************
*** Step 2.4 Child Mortality ***
********************************************************************************

codebook cm9a cm9b 
	//cm9a or cm9b: number of sons/daugters who have died provided by women

	
egen temp_f = rowtotal(cm9a cm9b), missing
	//Total child mortality reported by eligible women
replace temp_f = 0 if cm1==1 & cm8==2 | cm1==2 
	/*Assign a value of "0" for:
	- all eligible women who have ever gave birth but reported no child death 
	- all eligible women who never ever gave birth */
replace temp_f = 0 if no_fem_eligible==1	
	/*Assign a value of "0" for:
	- individuals living in households that have non-eligible women */
bysort	hh_id: egen child_mortality_f = sum(temp_f), missing
lab var child_mortality_f "Occurrence of child mortality reported by women"
tab child_mortality_f, miss
drop temp_f
	

gen child_mortality_m = .	
lab var child_mortality_m "Occurrence of child mortality reported by men"


egen child_mortality = rowmax(child_mortality_f)
lab var child_mortality "Total child mortality within household reported by women & men"
tab child_mortality, miss

	
*** Standard MPI *** 
/* The standard MPI indicator takes a value of "0" if women 
in the household reported mortality among children under 18 
in the last 5 years from the survey year.*/
************************************************************************

tab childu18_died_per_wom_5y, miss
		
replace childu18_died_per_wom_5y = 0 if cm1==1 & cm8==2 | cm1==2 
	/*Assign a value of "0" for:
	- all eligible women who have ever gave birth but reported no child death 
	- all eligible women who never ever gave birth */
replace childu18_died_per_wom_5y = 0 if no_fem_eligible==1	
	/*Assign a value of "0" for:
	- individuals living in households that have non-eligible women */
	
bysort hh_id: egen childu18_mortality_5y = sum(childu18_died_per_wom_5y), missing
replace childu18_mortality_5y = 0 if childu18_mortality_5y==. & child_mortality==0
label var childu18_mortality_5y "Under 18 child mortality within household past 5 years reported by women"
tab childu18_mortality_5y, miss		
	
gen hh_mortality_u18_5y = (childu18_mortality_5y==0)
replace hh_mortality_u18_5y = . if childu18_mortality_5y==.
lab var hh_mortality_u18_5y "Household had no under 18 child mortality in the last 5 years"
tab hh_mortality_u18_5y, miss 


*** Destitution MPI *** 
*** (same as standard MPI) ***
************************************************************************
clonevar hh_mortality_u = hh_mortality_u18_5y	


*** Harmonised MPI:  MICS 2010/11 - MICS 2013/14 *** 
	/*In the earlier survey, there is no birth history data. This means, 
	there is no information on the date of death of children who have died. 
	As such, we are not able to construct the indicator on child mortality 
	under 18 that occurred in the last 5 years for this survey. Instead, we 
	identify individuals as deprived if any children died in the household. 
	As such, for harmonisation purpose, we construct the same indicator 
	in this survey.*/ 
************************************************************************	
gen	hh_mortality_c = (child_mortality==0)
replace hh_mortality_c = . if child_mortality==.
replace hh_mortality_c = 1 if no_fem_eligible==1 
lab var hh_mortality_c "COT: HH had no child mortality"
tab hh_mortality_c, miss


clonevar hh_mortality_u_c = hh_mortality_c
lab var hh_mortality_u_c "COT-DST: HH had no child mortality"
	

********************************************************************************
*** Step 2.5 Electricity ***
********************************************************************************


*** Standard MPI ***
/*Members of the household are considered 
deprived if the household has no electricity */
***************************************************
clonevar electricity = hc8a 
codebook electricity, tab (10)
replace electricity = 0 if electricity==2 
replace electricity = . if electricity==9 	
label var electricity "Household has electricity"


*** Destitution MPI  ***
*** (same as standard MPI) ***
***************************************************
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

clonevar toilet = ws8  
codebook toilet, tab(30) 
codebook ws9, tab(30)  
	
clonevar shared_toilet = ws9 
recode shared_toilet (2=0)
replace shared_toilet=. if shared_toilet==9
tab ws9 shared_toilet, miss nol
	//0=no;1=yes;.=missing
	
		
*** Standard MPI ***
/*Members of the household are considered deprived if the household's 
sanitation facility is not improved (according to the SDG guideline) 
or it is improved but shared with other households*/
********************************************************************
gen	toilet_mdg = (toilet<=22 | toilet==31) & shared_toilet!=1
replace toilet_mdg = 0 if (toilet<=22 | toilet==31)  & shared_toilet==1 
replace toilet_mdg = . if toilet==.  | toilet==99
lab var toilet_mdg "Household has improved sanitation with MDG Standards"
tab toilet toilet_mdg, miss


*** Destitution MPI ***
/*Members of the household are considered deprived if household practises 
open defecation or uses other unidentifiable sanitation practises */
********************************************************************
gen	toilet_u = .
replace toilet_u = 0 if toilet==95 | toilet==96 
replace toilet_u = 1 if toilet!=95 & toilet!=96 & toilet!=. & toilet!=99
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

clonevar water = ws1  
clonevar timetowater = ws4  
clonevar ndwater = ws2  

	
*** Standard MPI ***
/* Members of the household are considered deprived if the household 
does not have access to improved drinking water (according to the SDG 
guideline) or safe drinking water is at least a 30-minute walk from 
home, roundtrip */
********************************************************************
codebook water, tab(99)	


gen	water_mdg     = 1 if water<=31 | water==41 | water==51 | water==91  				
replace water_mdg = 0 if water==32 | water==42 |  ///
						 water==81 | water==96 
	
replace water_mdg = 0 if water_mdg==1 & timetowater >= 30 & timetowater!=. & ///
						 timetowater!=998 & timetowater!=999 


replace water_mdg = . if water==. | water==99
replace water_mdg = 0 if water==91 & ///
						(ndwater==32 | ndwater==42 | ///
						 ndwater==81 | ndwater==96) 
lab var water_mdg "Household has drinking water with MDG standards (considering distance)"
tab water water_mdg, miss


*** Destitution MPI ***
/* Members of the household is identified as destitute if household 
does not have access to safe drinking water, or safe water is more 
than 45 minute walk from home, round trip.*/
********************************************************************
gen	water_u = .
replace water_u = 1 if water<=31 | water==41 | water==51 | water==91 					 
replace water_u = 0 if water==32  | water==42 |  ///
					   water==81 | water==96 						   
replace water_u = 0 if water_u==1 & timetowater> 45 & timetowater!=. & ///
					   timetowater!=998 & timetowater!=999 	
						   
replace water_u = . if water==99 | water==.
replace water_u = 0 if water==91 & ///
					   (ndwater==32 | ndwater==42 | ///
						ndwater==81 | ndwater==96)
						 
lab var water_u "Household has drinking water with MDG standards (45 minutes distance)"
tab water water_u, miss



********************************************************************************
*** Step 2.8 Housing ***
********************************************************************************

/* Members of the household are considered deprived if the household 
has a dirt, sand or dung floor */
clonevar floor = hc3
codebook floor, tab(99)
gen	floor_imp = 1
replace floor_imp = 0 if floor==11 | floor == 96 
replace floor_imp = . if floor==99 
replace floor_imp = . if floor == .
lab var floor_imp "Household has floor that it is not earth/sand/dung"
tab floor floor_imp, miss	


/* Members of the household are considered deprived if the household has wall 
made of natural or rudimentary materials */
clonevar wall = hc5
codebook wall, tab(99)
gen	wall_imp = 1 
replace wall_imp = 0 if wall<=26 | wall==96 	
replace wall_imp = . if wall == .
lab var wall_imp "Household has wall that it is not of low quality materials"
tab wall wall_imp, miss	
	

/* Members of the household are considered deprived if the household has roof 
made of natural or rudimentary materials */
clonevar roof = hc4
codebook roof, tab(99)		
gen	roof_imp = 1 
replace roof_imp = 0 if roof<=23 |  roof==96 	
replace roof_imp = . if roof== . 
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


*** Destitution MPI ***
/* Members of the household is deprived in housing if two out 
of three components (roof and walls; OR floor and walls; OR 
roof and floor) the are constructed from low quality materials. */
**************************************************************
gen housing_2 = 1
replace housing_2 = 0 if (floor_imp==0 & wall_imp==0 & roof_imp==1) | ///
						 (floor_imp==0 & wall_imp==1 & roof_imp==0) | ///
						 (floor_imp==1 & wall_imp==0 & roof_imp==0) | ///
						 (floor_imp==0 & wall_imp==0 & roof_imp==0)
replace housing_2 = . if floor_imp==. & wall_imp==. & roof_imp==.
lab var housing_2 "Household has one of three aspects(either roof,floor/walls) that it is not low quality material"
tab housing_2, miss
rename housing_2 housing_u
lab var housing_u "Household has one of three aspects(either roof,floor/walls) that is not low quality material"


********************************************************************************
*** Step 2.9 Cooking Fuel ***
********************************************************************************
/*
Solid fuel are solid materials burned as fuels, which includes coal as well as 
solid biomass fuels (wood, animal dung, crop wastes and charcoal). 

Source: 
https://apps.who.int/iris/bitstream/handle/10665/141496/9789241548885_eng.pdf
*/

clonevar cookingfuel = hc6  


*** Standard MPI ***
/* Members of the household are considered deprived if the 
household uses solid fuels and solid biomass fuels for cooking. */
*****************************************************************
codebook cookingfuel, tab(99)

gen	cooking_mdg = 1
replace cooking_mdg = 0 if cookingfuel>5 & cookingfuel<95 
replace cooking_mdg = . if cookingfuel==. |cookingfuel==99
lab var cooking_mdg "Household has cooking fuel according to MDG standards"	 
tab cookingfuel cooking_mdg, miss	


*** Destitution MPI ***
*** (same as standard MPI) ***
****************************************
gen	cooking_u = cooking_mdg
lab var cooking_u "Household uses clean fuels for cooking"


********************************************************************************
*** Step 2.10 Assets ownership ***
********************************************************************************


recode hc8c (2=0 "no")(1=1 "yes"), gen (television) 
gen bw_television   = .

recode hc8b (2=0 "no")(1=1 "yes"), gen (radio)
recode hc8d (2=0 "no")(1=1 "yes"), gen (telephone)
recode hc9b (2=0 "no")(1=1 "yes"), gen (mobiletelephone) 
recode hc8e (2=0 "no")(1=1 "yes"), gen (refrigerator)
recode hc8p (2=0 "no")(1=1 "yes"), gen (car)
recode hc9c (2=0 "no")(1=1 "yes"), gen (bicycle)
recode hc9d (2=0 "no")(1=1 "yes"), gen (motorbike) 
recode hc8j (2=0 "no")(1=1 "yes"), gen (computer)
gen animal_cart = .


foreach var in television radio telephone mobiletelephone refrigerator ///
			   car bicycle motorbike computer animal_cart  {
replace `var' = 0 if `var'==2 
replace `var' = . if `var'==9 | `var'==99 | `var'==8 | `var'==98 
}
	//Missing values replaced



	//Group telephone and mobiletelephone as a single variable
replace telephone=1 if telephone==0 & mobiletelephone==1
replace telephone=1 if telephone==. & mobiletelephone==1


	//Label indicators
lab var television "Household has television"
lab var radio "Household has radio"	
lab var telephone "Household has telephone (landline/mobilephone)"	
lab var refrigerator "Household has refrigerator"
lab var car "Household has car"
lab var bicycle "Household has bicycle"	
lab var motorbike "Household has motorbike"
lab var computer "Household has computer"
lab var animal_cart "Household has animal cart"


*** Standard MPI ***
/* Members of the household are considered deprived in assets if the household 
does not own more than one of: radio, TV, telephone, bike, motorbike, 
refrigerator, computer or animal cart and does not own a car or truck.*/
*****************************************************************************
egen n_small_assets2 = rowtotal(television radio telephone refrigerator bicycle motorbike computer animal_cart), missing
lab var n_small_assets2 "Household Number of Small Assets Owned" 
   
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
recode hh_mortality_u18_5y  (0=1)(1=0) , gen(d_cm)
recode hh_nutrition_uw_st 	(0=1)(1=0) , gen(d_nutr)
recode hh_child_atten 		(0=1)(1=0) , gen(d_satt)
recode hh_years_edu6 		(0=1)(1=0) , gen(d_educ)
recode electricity 			(0=1)(1=0) , gen(d_elct)
recode water_mdg 			(0=1)(1=0) , gen(d_wtr)
recode toilet_mdg 			(0=1)(1=0) , gen(d_sani)
recode housing_1 			(0=1)(1=0) , gen(d_hsg)
recode cooking_mdg 			(0=1)(1=0) , gen(d_ckfl)
recode hh_assets2 			(0=1)(1=0) , gen(d_asst)
 

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


*** Rename indicators for changes over time estimation ***	
recode hh_mortality_c       (0=1)(1=0) , gen(d_cm_01)
recode hh_nutrition_uw_st 	(0=1)(1=0) , gen(d_nutr_01)
recode hh_child_atten 		(0=1)(1=0) , gen(d_satt_01)
recode hh_years_edu6 		(0=1)(1=0) , gen(d_educ_01)
recode electricity 			(0=1)(1=0) , gen(d_elct_01)
recode water_mdg 			(0=1)(1=0) , gen(d_wtr_01)
recode toilet_mdg 			(0=1)(1=0) , gen(d_sani_01)
recode housing_1 			(0=1)(1=0) , gen(d_hsg_01)
recode cooking_mdg 			(0=1)(1=0) , gen(d_ckfl_01)
recode hh_assets2 			(0=1)(1=0) , gen(d_asst_01)	
	

recode hh_mortality_u_c      (0=1)(1=0) , gen(dst_cm_01)
recode hh_nutrition_uw_st_u (0=1)(1=0) , gen(dst_nutr_01)
recode hh_child_atten_u 	(0=1)(1=0) , gen(dst_satt_01)
recode hh_years_edu_u 		(0=1)(1=0) , gen(dst_educ_01)
recode electricity_u		(0=1)(1=0) , gen(dst_elct_01)
recode water_u	 			(0=1)(1=0) , gen(dst_wtr_01)
recode toilet_u 			(0=1)(1=0) , gen(dst_sani_01)
recode housing_u 			(0=1)(1=0) , gen(dst_hsg_01)
recode cooking_u			(0=1)(1=0) , gen(dst_ckfl_01)
recode hh_assets2_u 		(0=1)(1=0) , gen(dst_asst_01)


	/*In this survey, the harmonised 'region_01' variable is the 
	same as the standardised 'region' variable.*/	
clonevar region_01 = region 


*** Keep main variables require for MPI calculation ***
keep hh_id ind_id psu strata subsample weight ///
area region region_01 agec4 agec2 headship ///
d_cm d_nutr d_satt d_educ d_elct d_wtr d_sani d_hsg d_ckfl d_asst /// 
d_cm_01 d_nutr_01 d_satt_01 d_educ_01 ///
d_elct_01 d_wtr_01 d_sani_01 d_hsg_01 d_ckfl_01 d_asst_01


order hh_id ind_id psu strata subsample weight ///
area region region_01 agec4 agec2 headship ///
d_cm d_nutr d_satt d_educ d_elct d_wtr d_sani d_hsg d_ckfl d_asst ///
d_cm_01 d_nutr_01 d_satt_01 d_educ_01 ///
d_elct_01 d_wtr_01 d_sani_01 d_hsg_01 d_ckfl_01 d_asst_01



*** Generate coutry and survey details for estimation ***
char _dta[cty] "Vietnam"
char _dta[ccty] "VNM"
char _dta[year] "2013-2014" 	
char _dta[survey] "MICS"
char _dta[ccnum] "704"
char _dta[type] "micro"
char _dta[class] "old_survey"


*** Sort, compress and save data for estimation ***
sort ind_id
compress
la da "Micro data for `_dta[ccty]' (`_dta[ccnum]') from `c(current_date)' (`c(current_time)')."
save "$path_out/vnm_mics13-14.dta", replace 
