********************************************************************************
/*
Adapted from:
Oxford Poverty and Human Development Initiative (OPHI), University of Oxford. 
Global Multidimensional Poverty Index - Thailand MICS 2015-16 
[STATA do-file]. Available from OPHI website: http://ophi.org.uk/  

For further queries, contact: ophi@qeh.ox.ac.uk
*/
********************************************************************************

clear all 
set more off


global path_in "../../data/MICS/Thailand MICS5 and Thailand Selected 14 Provinces MICS5 Datasets/Thailand MICS5 Datasets/Thailand MICS5 Datasets/Thailand MICS5 SPSS Datasets" 	
global path_out "../../data/MPI/tha_mics1516_test"
global path_ado "ado"




********************************************************************************
*** Step 1: Data preparation 
********************************************************************************
	

********************************************************************************
*** Step 1.1 CH - CHILDREN's RECODE (under 5)
********************************************************************************	

import spss using "$path_in/ch.sav", clear

rename _all, lower	

gen double ind_id = hh1*100000 + hh2*100 + uf4 
format ind_id %20.0g


duplicates report ind_id


gen child_CH=1 


*** Variable: SEX *** 
clonevar gender = hl4

*** Variable: AGE ***
clonevar age_days = caged
replace age_days = . if caged==9999 
replace age_days = . if caged < 0  

gen str6 ageunit = "days"
lab var ageunit "Days"


*** Variable: BODY WEIGHT (KILOGRAMS) ***
codebook an3, tab (999)
clonevar weight = an3	
replace weight = . if an3>=99 
	

*** Variable: HEIGHT (CENTIMETERS)
codebook an4, tab (999)
clonevar height = an4
replace height = . if an4>=999 

	
*** Variable: MEASURED STANDING/LYING DOWN	
codebook an4a
gen measure = "l" if an4a==1 
replace measure = "h" if an4a==2 
replace measure = " " if an4a==9 | an4a==0 | an4a==. 

	
*** Variable: OEDEMA ***
gen oedema = "n"  

*** Variable: INDIVIDUAL CHILD SAMPLING WEIGHT ***
gen sw = chweight


adopath + "$path_ado/igrowup_stata"
gen str100 reflib = "$path_ado/igrowup_stata"
lab var reflib "Directory of reference tables"
gen str100 datalib = "$path_out"  
lab var datalib "Directory for datafiles"
gen str30 datalab = "children_nutri_tha" 
lab var datalab "Working file"


igrowup_restricted reflib datalib datalab gender age_days ageunit weight ///
height measure oedema sw


use "$path_out/children_nutri_tha_z_rc.dta", clear 

	
gen	z_scorewa = _zwei
replace z_scorewa = . if _fwei==1 
lab var z_scorewa "z-score weight-for-age WHO"

*** Standard MPI ***
gen	underweight = (_zwei < -2.0) 
replace underweight = . if _zwei == . | _fwei==1
lab var underweight  "Child is undernourished (weight-for-age) 2sd - WHO"
tab underweight [aw=chweight], miss 


gen stunting = (_zlen < -2.0)
replace stunting = . if _zlen == . | _flen==1
lab var stunting "Child is stunted (length/height-for-age) 2sd - WHO"
tab stunting [aw=chweight], miss


gen wasting = (_zwfl < - 2.0)
replace wasting = . if _zwfl == . | _fwfl == 1
lab var wasting  "Child is wasted (weight-for-length/height) 2sd - WHO"
tab wasting [aw=chweight], miss 


*** Destitution MPI  ***
gen	underweight_u = (_zwei < -3.0) 
replace underweight_u = . if _zwei == . | _fwei==1
lab var underweight_u  "Child is undernourished (weight-for-age) 3sd - WHO"


gen stunting_u = (_zlen < -3.0)
replace stunting_u = . if _zlen == . | _flen==1
lab var stunting_u "Child is stunted (length/height-for-age) 3sd - WHO"


gen wasting_u = (_zwfl < - 3.0)
replace wasting_u = . if _zwfl == . | _fwfl == 1
lab var wasting_u  "Child is wasted (weight-for-length/height) 3sd - WHO"

 
count if _fwei==1 | _flen==1
	/*Thailand MICS 2015-16: 55 children were replaced as '.' 
	because they have extreme z-scores that are biologically implausible.*/ 
 
 
clonevar weight_ch = chweight
label var weight_ch "sample weight child under 5"	


	//Retain relevant variables:
keep ind_id child_CH uf4 weight_ch underweight* stunting* wasting*  
order ind_id child_CH uf4 weight_ch underweight* stunting* wasting*
sort ind_id
save "$path_out/THA15-16_CH.dta", replace


	

********************************************************************************
*** Step 1.2  BH - BIRTH RECODE 
*** (All females 15-49 years who ever gave birth)  
********************************************************************************
	
	/* Note: There is no BH data file for Thailand MICS 2015-16. Hence this 
	section has been deactivated */


********************************************************************************
*** Step 1.3  WM - WOMEN's RECODE  
*** (All eligible females 15-49 years in the household)
********************************************************************************
import spss using "$path_in/wm.sav", clear 

	
rename _all, lower	

	
*** Generate individual unique key variable required for data merging
*** hh1=cluster number;  
*** hh2=household number; 
*** wm4=respondent's line number
gen double ind_id = hh1*100000 + hh2*100 + wm4
format ind_id %20.0g
label var ind_id "Individual ID"

duplicates report ind_id

gen women_WM =1 
	//Identification variable for observations in WM recode

	
tab wb2, miss
	//Women 15-49 years
	
tab cm1 cm8, miss
	/*Women who has never ever given birth will not have information on 
	child mortality*/
	
	
	//Retain relevant variables:	
lookfor religion	
gen religion_wom = .
lab var religion_wom "women's religion"	


lookfor ethnicity
gen ethnic_wom = .
lab var ethnic_wom "women's ethnicity"	


lookfor insurance
gen insurance_wom = .
label var insurance_wom "women have health insurance"	


lookfor marital	
codebook mstatus ma6, tab (10)
tab mstatus ma6, miss 
gen marital = 1 if mstatus == 3 & ma6==.
	//1: Never married
replace marital = 2 if mstatus == 1 & ma6==.
	//2: Currently married
replace marital = 3 if mstatus == 2 & ma6==1
	//3: Widowed	
replace marital = 4 if mstatus == 2 & ma6==2
	//4: Divorced	
replace marital = 5 if mstatus == 2 & ma6==3
	//5: Separated/not living together	
label define lab_mar 1"never married" 2"currently married" 3"widowed" ///
4"divorced" 5"not living together"
label values marital lab_mar	
label var marital "Marital status of household member"
tab marital, miss
tab ma6 marital, miss
tab mstatus marital, miss
rename marital marital_wom		

	//Retain relevant variables:	
keep wm7 cm1 cm8 cm9a cm9b ind_id women_WM *_wom 
order wm7 cm1 cm8 cm9a cm9b ind_id women_WM *_wom
sort ind_id
save "$path_out/THA15-16_WM.dta", replace


********************************************************************************
*** Step 1.4  MN - MEN'S RECODE 
***(All eligible man: 15-59 years in the household) 
********************************************************************************

import spss using "$path_in/mn.sav", clear 

	
rename _all, lower

	
*** Generate individual unique key variable required for data merging
*** hh1=cluster number;  
*** hh2=household number; 
*** mwm4=respondent's line number
gen double ind_id = hh1*100000 + hh2*100 + mwm4
format ind_id %20.0g
label var ind_id "Individual ID"

duplicates report ind_id

gen men_MN=1 	
	//Identification variable for observations in MR recode


	//Retain relevant variables:
lookfor religion	
gen religion_men = . 
lab var religion_men "men's religion"	


lookfor ethnicity
gen ethnic_men = .
lab var ethnic_men "men's ethnicity"

	
lookfor insurance	
gen insurance_men = .
label var insurance_men "men have health insurance"	


lookfor marital	
codebook mmstatus mma6, tab (10)
tab mmstatus mma6, miss 
gen marital = 1 if mmstatus == 3 & mma6==.
	//1: Never married
replace marital = 2 if mmstatus == 1 & mma6==.
	//2: Currently married
replace marital = 3 if mmstatus == 2 & mma6==1
	//3: Widowed	
replace marital = 4 if mmstatus == 2 & mma6==2
	//4: Divorced	
replace marital = 5 if mmstatus == 2 & mma6==3
	//5: Separated/not living together	
label define lab_mar 1"never married" 2"currently married" 3"widowed" ///
4"divorced" 5"not living together"
label values marital lab_mar	
label var marital "Marital status of household member"
tab marital, miss
tab mma6 marital, miss
tab mmstatus marital, miss
rename marital marital_men


	//Retain relevant variables:	
keep mcm1 mcm8 mcm9a mcm9b ind_id men_MN *_men 
order mcm1 mcm8 mcm9a mcm9b ind_id men_MN *_men
sort ind_id
save "$path_out/THA15-16_MN.dta", replace


********************************************************************************
*** Step 1.5 HH - HOUSEHOLD RECODE 
***(All households interviewed) 
********************************************************************************

import spss using "$path_in/hh.sav", clear 
	
rename _all, lower	


*** Generate individual unique key variable required for data merging
*** hh1=cluster number;  
*** hh2=household number; 
gen	double hh_id = hh1*100 + hh2 
format	hh_id %20.0g
lab var hh_id "Household ID"


save "$path_out/THA15-16_HH.dta", replace


********************************************************************************
*** Step 1.6 HL - HOUSEHOLD MEMBER  
********************************************************************************

import spss using "$path_in/hl.sav", clear 
	
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


*** Merging WM Recode 
*****************************************
merge 1:1 ind_id using "$path_out/THA15-16_WM.dta"
drop _merge


*** Merging HH Recode 
*****************************************
merge m:1 hh_id using "$path_out/THA15-16_HH.dta"
tab hh9 if _m==2
drop  if _merge==2
	//Drop households that were not interviewed 
drop _merge


*** Merging MN Recode 
*****************************************
merge 1:1 ind_id using "$path_out/THA15-16_MN.dta"
drop _merge


*** Merging CH Recode 
*****************************************
merge 1:1 ind_id using "$path_out/THA15-16_CH.dta"
drop _merge


sort ind_id


********************************************************************************
*** Step 1.8 CONTROL VARIABLES
********************************************************************************


*** No Eligible Women 15-49 years
*****************************************
gen	fem_eligible = (hl7>0) if hl7!=.
bys	hh_id: egen hh_n_fem_eligible = sum(fem_eligible) 	
gen	no_fem_eligible = (hh_n_fem_eligible==0) 									
	//Takes value 1 if the household had no eligible females for an interview
lab var no_fem_eligible "Household has no eligible women"
tab no_fem_eligible, miss


*** No Eligible Men 
*****************************************
gen	male_eligible = (hl7a>0) if hl7a!=.
bys	hh_id: egen hh_n_male_eligible = sum(male_eligible)  
gen	no_male_eligible = (hh_n_male_eligible==0) 	
	//Takes value 1 if the household had no eligible males for an interview
lab var no_male_eligible "Household has no eligible man"
tab no_male_eligible, miss

	
*** No Eligible Children 0-5 years
***************************************** 
count if child_CH==1
count if hl7b>0 & hl7b!=.
gen	child_eligible = (hl7b>0 | child_CH==1) 
bys	hh_id: egen hh_n_children_eligible = sum(child_eligible)  
gen	no_child_eligible = (hh_n_children_eligible==0) 
	//Takes value 1 if there were no eligible children for anthropometrics
lab var no_child_eligible "Household has no children eligible"	
tab no_child_eligible, miss
	

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
recode relationship (1=1)(2=2)(3 13=3)(4/12=4)(14=6)(96=5)(98=.)
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


//Religion of the household head
lookfor religion
clonevar religion_hh = hc1a
label var religion_hh "Religion of household head"


//Ethnicity of the household head
lookfor ethnicity
gen ethnic_hh = .
label var ethnic_hh "Ethnicity of household head"



//Subnational region
	/*Thailand MICS 2015-16: The survey was designed to provide estimates 
	for a large number of indicators at the national level, for urban and rural 
	areas, and for 5 regions. In addition, the results are produced for 14 
	individual provinces. However, we use the 5 regions because that is what is 
	used in the survey report (p.3) */ 
lookfor region
codebook hh7, tab (100)
decode hh7, gen(temp)
replace temp =  proper(temp)
encode temp, gen(region)
lab var region "Region for subnational decomposition"
drop temp
codebook region, tab (99)


********************************************************************************
***  Step 2 Data preparation  ***
***  Standardization of the 10 Global MPI indicators 
***  Identification of non-deprived & deprived individuals  
********************************************************************************


********************************************************************************
*** Step 2.1 Years of Schooling ***
********************************************************************************

	/*According to the survey report (p.131), in Thailand, there are 6 grades 
	of primary school and 6 grades of secondary school. Children enter primary 
	school at 6 years of age and secondary school at age 12.*/

codebook ed4a, tab (99)
clonevar edulevel = ed4a 
	//Highest educational level attended
replace edulevel = . if ed4a==. | ed4a==8 |ed4a==98 | ed4a==99  
	//ed4a=8/98/99 are missing values 
replace edulevel = 0 if ed3==2 
	//Those who never attended school are replaced as '0'
label var edulevel "Highest educational level attended"

codebook ed4b, tab (99)
clonevar eduhighyear = ed4b 
	//Highest grade of education completed
replace eduhighyear = .  if ed4b==. | ed4b==97 | ed4b==98 | ed4b==99 
	//ed4b=97/98/99 are missing values
replace eduhighyear = 0  if ed3==2 
	//Those who never attended school are replaced as '0'
lab var eduhighyear "Highest year of education completed"


*** Cleaning inconsistencies
replace edulevel = 0 if age<10  
replace eduhighyear = 0 if age<10 
	/*At this point, we disregard the years of education of household members 
	younger than 10 years by replacing the relevant variables with '0 years' 
	since they are too young to have completed 6 years of schooling.*/ 
replace eduhighyear = 0 if edulevel<1
	//Early childhood education has no grade


*** Now we create the years of schooling
tab eduhighyear edulevel, miss
gen	eduyears = eduhighyear
replace eduyears = eduhighyear + 6 if edulevel==2
replace eduyears = 6 if eduhighyear==. & edulevel==2
replace eduyears = eduhighyear + 9 if edulevel==3  
replace eduyears = 9 if eduhighyear==. & edulevel==3
	/*Professional education assumed to start after 9 years of general 
	education. Based on information from Thailand NSO and NESDB */
replace eduyears = eduhighyear + 12 if edulevel==4 
replace eduyears = 12 if eduhighyear==. & edulevel==4
	/*Diploma after 12 years of education, 6 years of primary + 6 years of 
	secondary */
replace eduyears = eduhighyear + 12 if edulevel==5
replace eduyears = 12 if eduhighyear==. & edulevel==5
	//University assumed to start after 12 years of general education 
replace eduyears = eduhighyear + 16 if edulevel==6
	//Bachelor degree assumed to be 4 years, plus 12 years of general education 
replace eduyears = eduhighyear + 18 if edulevel==7
	//Doctoral degree assumed to start after 18 years 


*** Checking for further inconsistencies 
replace eduyears = . if age<=eduyears & age>0 
	/*There are cases in which the years of schooling are greater than the 
	age of the individual. This is replaced as invalid.*/
replace eduyears = 0 if age< 10
replace eduyears = 0 if (age==10 | age==11) & eduyears < 6 
	/*The variable "eduyears" was replaced with a '0' for ineligible household 
	members, i.e.: those who have not completed 6 years of schooling following 
	their starting school age */
lab var eduyears "Total number of years of education accomplished"
tab eduyears, miss
tab eduyears edulevel, miss	


	/*A control variable is created on whether there is information on 
	years of education for at least 2/3 of the household members aged 10 years 
	and older */	
gen temp = 1 if eduyears!=. & age>=10 & age!=.
bysort	hh_id: egen no_missing_edu = sum(temp)
	/*Total household members who are 10 years and older with no missing 
	years of education */
gen temp2 = 1 if age>=10 & age!=.
bysort hh_id: egen hhs = sum(temp2)
	/*Total number of household members who are 10 years and older */
replace no_missing_edu = no_missing_edu/hhs
replace no_missing_edu = (no_missing_edu>=2/3)
	/*Identify whether there is information on years of education for at 
	least 2/3 of the household members aged 10 years and older */
tab no_missing_edu, miss
	//The value for 0 (missing) is 0.26% 
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
	//Final variable missing if household has info for < 2/3 of members 
lab var hh_years_edu6 "HH has at least one member with 6 years of edu"
tab hh_years_edu6, miss


*** Destitution MPI ***
/*The entire household is considered deprived if no eligible 
household member has completed at least one year of schooling. */
******************************************************************* 
gen	years_edu1 = (eduyears>=1)
replace years_edu1 = . if eduyears==.
bysort	hh_id: egen hh_years_edu_u = max(years_edu1)
replace hh_years_edu_u = . if hh_years_edu_u==0 & no_missing_edu==0
lab var hh_years_edu_u "DST: HH has at least one member with 1 year of edu"
tab hh_years_edu_u, miss 


********************************************************************************
*** Step 2.2 Child School Attendance ***
********************************************************************************

gen	attendance = .
replace attendance = 1 if ed5==1 
	//Replace attendance with '1' if currently attending school	
replace attendance = 0 if ed5==2 
	//Replace attendance with '0' if currently not attending school	
replace attendance = 0 if ed3==2 
	//Replace attendance with '0' if never ever attended school	
replace attendance = 0 if age<4 | age>24 
	//Replace attendance with '0' for individuals who are not of school age 	
tab attendance, miss


*** Standard MPI ***
/*The entire household is considered deprived if any school-aged 
child is not attending school up to class 8. */ 
******************************************************************* 
gen	child_schoolage = (schage>=6 & schage<=14)
	/*In Thailand, the official school entrance age for primary school is 6 
	years. So, age range is 6-14 (=6+8) */

	
	/*A control variable is created on whether there is no information on 
	school attendance for at least 2/3 of the school age children */
count if child_schoolage==1 & attendance==.
	//Understand how many eligible school aged children are not attending school 	
gen temp = 1 if child_schoolage==1 & attendance!=.
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
label var no_missing_atten "No missing school attendance for at least 2/3 of the school aged children"		
drop temp temp2 hhs
	
bysort	hh_id: egen hh_children_schoolage = sum(child_schoolage)
replace hh_children_schoolage = (hh_children_schoolage>0) 
lab var hh_children_schoolage "HH has children in school age"

gen	child_not_atten = (attendance==0) if child_schoolage==1
replace child_not_atten = . if attendance==. & child_schoolage==1
bysort	hh_id: egen any_child_not_atten = max(child_not_atten)
gen	hh_child_atten = (any_child_not_atten==0) 
replace hh_child_atten = . if any_child_not_atten==.
replace hh_child_atten = 1 if hh_children_schoolage==0
replace hh_child_atten = . if hh_child_atten==1 & no_missing_atten==0 
lab var hh_child_atten "HH has all school age children up to class 8 in school"
tab hh_child_atten, miss

	
*** Destitution MPI ***
/*The entire household is considered deprived if any school-aged 
child is not attending school up to class 6. */ 
******************************************************************* 
gen	child_schoolage_6 = (schage>=6 & schage<=12)
	/*In Thailand, the official school entrance age is 6 years  
	  So, age range is 6-12 (=6+6) */

	
	/*A control variable is created on whether there is no information on 
	school attendance for at least 2/3 of the children attending school up to 
	class 6 */	
gen temp = 1 if child_schoolage_6==1 & attendance!=.
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
label var no_missing_atten_u "No missing school attendance for at least 2/3 of the school aged children"		
drop temp temp2 hhs		
		
bysort	hh_id: egen hh_children_schoolage_6 = sum(child_schoolage_6)
replace hh_children_schoolage_6 = (hh_children_schoolage_6>0) 
lab var hh_children_schoolage_6 "HH has children in school age (6 years of school)"

gen	child_atten_6 = (attendance==1) if child_schoolage_6==1
replace child_atten_6 = . if attendance==. & child_schoolage_6==1
bysort	hh_id: egen any_child_atten_6 = max(child_atten_6)
gen	hh_child_atten_u = (any_child_atten_6==1) 
replace hh_child_atten_u = . if any_child_atten_6==.
replace hh_child_atten_u = 1 if hh_children_schoolage_6==0
replace hh_child_atten_u = . if hh_child_atten_u==0 & no_missing_atten_u==0 
lab var hh_child_atten_u "DST: HH has at least one school age children up to class 6 in school"
tab hh_child_atten_u, miss


********************************************************************************
*** Step 2.3 Nutrition ***
********************************************************************************


********************************************************************************
*** Step 2.3a Child Nutrition ***
********************************************************************************

*** Child Underweight Indicator ***
************************************************************************

*** Standard MPI ***
bysort hh_id: egen temp = max(underweight)
gen	hh_no_underweight = (temp==0) 
replace hh_no_underweight = . if temp==.
replace hh_no_underweight = 1 if no_child_eligible==1 
lab var hh_no_underweight "HH has no child underweight - 2 stdev"
drop temp


*** Destitution MPI  ***
bysort hh_id: egen temp = max(underweight_u)
gen	hh_no_underweight_u = (temp==0) 
replace hh_no_underweight_u = . if temp==.
replace hh_no_underweight_u = 1 if no_child_eligible==1 
lab var hh_no_underweight_u "DST: HH has no child underweight"
drop temp


*** Child Stunting Indicator ***
************************************************************************

*** Standard MPI ***
bysort hh_id: egen temp = max(stunting)
gen	hh_no_stunting = (temp==0) 
replace hh_no_stunting = . if temp==.
replace hh_no_stunting = 1 if no_child_eligible==1 
lab var hh_no_stunting "HH has no child stunted - 2 stdev"
drop temp


*** Destitution MPI  ***
bysort hh_id: egen temp = max(stunting_u)
gen	hh_no_stunting_u = (temp==0) 
replace hh_no_stunting_u = . if temp==.
replace hh_no_stunting_u = 1 if no_child_eligible==1 
lab var hh_no_stunting_u "DST: HH has no child stunted"
drop temp


*** Child Wasting Indicator ***
************************************************************************

*** Standard MPI ***
bysort hh_id: egen temp = max(wasting)
gen	hh_no_wasting = (temp==0) 
replace hh_no_wasting = . if temp==.
replace hh_no_wasting = 1 if no_child_eligible==1 
lab var hh_no_wasting "HH has no child wasted - 2 stdev"
drop temp


*** Destitution MPI  ***
bysort hh_id: egen temp = max(wasting_u)
gen	hh_no_wasting_u = (temp==0) 
replace hh_no_wasting_u = . if temp==.
replace hh_no_wasting_u = 1 if no_child_eligible==1 
lab var hh_no_wasting_u "DST: HH has no child wasted"
drop temp


*** Child Either Underweight or Stunted Indicator ***
************************************************************************

*** Standard MPI ***
gen uw_st = 1 if stunting==1 | underweight==1
replace uw_st = 0 if stunting==0 & underweight==0
replace uw_st = . if stunting==. & underweight==.

bysort hh_id: egen temp = max(uw_st)
gen	hh_no_uw_st = (temp==0) 
replace hh_no_uw_st = . if temp==.
replace hh_no_uw_st = 1 if no_child_eligible==1
lab var hh_no_uw_st "HH has no child underweight or stunted"
drop temp


*** Destitution MPI  ***
gen uw_st_u = 1 if stunting_u==1 | underweight_u==1
replace uw_st_u = 0 if stunting_u==0 & underweight_u==0
replace uw_st_u = . if stunting_u==. & underweight_u==.

bysort hh_id: egen temp = max(uw_st_u)
gen	hh_no_uw_st_u = (temp==0) 
replace hh_no_uw_st_u = . if temp==.
replace hh_no_uw_st_u = 1 if no_child_eligible==1 
lab var hh_no_uw_st_u "DST: HH has no child underweight or stunted"
drop temp


********************************************************************************
*** Step 2.3b Household Nutrition Indicator ***
********************************************************************************

*** Standard MPI ***
gen	hh_nutrition_uw_st = 1
replace hh_nutrition_uw_st = 0 if hh_no_uw_st==0
replace hh_nutrition_uw_st = . if hh_no_uw_st==.
replace hh_nutrition_uw_st = 1 if no_child_eligible==1   		
lab var hh_nutrition_uw_st "HH has no individuals malnourished"
tab hh_nutrition_uw_st, miss


*** Destitution MPI ***
gen	hh_nutrition_uw_st_u = 1
replace hh_nutrition_uw_st_u = 0 if hh_no_uw_st_u==0
replace hh_nutrition_uw_st_u = . if hh_no_uw_st_u==.
replace hh_nutrition_uw_st_u = 1 if no_child_eligible==1   		
lab var hh_nutrition_uw_st_u "DST: HH has no individuals malnourished"
tab hh_nutrition_uw_st_u, miss


********************************************************************************
*** Step 2.4 Child Mortality ***
********************************************************************************

codebook cm9a cm9b mcm9a mcm9b
	//cm9a or mcm9a: number of sons who have died 
	//cm9b or mcm9b: number of daughters who have died

	
tab cm1 cm8, miss
	/*Identify the number of women who never gave birth 
	but has birth history data: 0 women.
	We make use of the birth history information from
	these women.*/
	
		
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
	

egen temp_m = rowtotal(mcm9a mcm9b), missing
	//Total child mortality reported by eligible men	
replace temp_m = 0 if mcm1==1 & mcm8==2 | mcm1==2 
	/*Assign a value of "0" for:
	- all eligible men who ever fathered children but reported no child death 
	- all eligible men who never fathered children */
replace temp_m = 0 if no_male_eligible==1	
	/*Assign a value of "0" for:
	- individuals living in households that have non-eligible women */
bysort	hh_id: egen child_mortality_m = sum(temp_m), missing	
lab var child_mortality_m "Occurrence of child mortality reported by men"
tab child_mortality_m, miss
drop temp_m


egen child_mortality = rowmax(child_mortality_f child_mortality_m)
lab var child_mortality "Total child mortality within household"
tab child_mortality, miss

	
*** Standard MPI *** 
	/*The usual definition for this indicator is that household members are
	identified as deprived if any children under 18 died in the household in 
	the last 5 years from the survey year. However, in the case of this 
	survey, there is no birth history data. This means, there is no information 
	on the date of death of children who have died. As such we are not able to 
	construct the indicator on child mortality under 18 that occurred in the 
	last 5 years. Instead, we identify individuals as deprived if any children 
	died in the household. */
************************************************************************
gen	hh_mortality = (child_mortality==0)
	/*Household is replaced with a value of "1" if there is no incidence of 
	child mortality*/
replace hh_mortality = . if child_mortality==.
replace hh_mortality = 1 if no_fem_eligible==1 
lab var hh_mortality "HH had no child mortality"
tab hh_mortality, miss


gen hh_mortality_u18_5y = .
lab var hh_mortality_u18_5y "HH had no under 18 child mortality in the last 5 years"


*** Destitution MPI *** 
*** (same as standard MPI) ***
************************************************************************
clonevar hh_mortality_u = hh_mortality		
lab var hh_mortality_u "DST: HH had no child mortality"


********************************************************************************
*** Step 2.5 Electricity ***
********************************************************************************

*** Standard MPI ***
/*Members of the household are considered 
deprived if the household has no electricity */
****************************************
clonevar electricity = hc8a 
codebook electricity, tab (10)
replace electricity = 0 if electricity==2
replace electricity = . if electricity==9 
label var electricity "HH has electricity"


*** Destitution MPI  ***
*** (same as standard MPI) ***
****************************************
gen electricity_u = electricity
label var electricity_u "DST: HH has electricity"


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
codebook ws9, tab(30)  	
clonevar shared_toilet = ws9 
recode shared_toilet (2=0)
	
*** Standard MPI ***
/*Members of the household are considered deprived if the household's 
sanitation facility is not improved (according to the SDG guideline) 
or it is improved but shared with other households*/
********************************************************************
codebook toilet, tab(30)
gen	toilet_mdg = (toilet<=22 & shared_toilet!=1) 
replace toilet_mdg = 0 if toilet == 14 
replace toilet_mdg = 0 if toilet<=22 & shared_toilet==1 
replace toilet_mdg = . if toilet==. | toilet==99
lab var toilet_mdg "HH has improved sanitation"
tab toilet_mdg, miss


*** Destitution MPI ***
/*Members of the household are considered deprived if household practises 
open defecation or uses other unidentifiable sanitation practises */
********************************************************************
gen	toilet_u = .
replace toilet_u = 0 if toilet==95 | toilet==96 
replace toilet_u = 1 if toilet!=95 & toilet!=96 & toilet!=. & toilet!=99
lab var toilet_u "DST: HH does not practise open defecation or others"
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

gen	water_mdg = 1 if water==11 | water==12 | water==13 | water==14 | ///
					 water==21 | water==31 | water==41 | water==51 | ///
					 water==91	
					 
replace water_mdg = 0 if water==32 | water==42 | water==61 | ///
						 water==71 | water==81 | water==96

replace water_mdg = 0 if water_mdg==1 & timetowater >= 30 & timetowater!=. & ///
						 timetowater!=998

replace water_mdg = . if water==. | water==99
replace water_mdg = 0 if water==91 & ///
						 (ndwater==32 | ndwater==42 | ndwater==61 | ///
						  ndwater==71 | ndwater==81 | ndwater==96) 
lab var water_mdg "HH has safe drinking water (considering distance)"
tab water water_mdg, miss


*** Destitution MPI ***
/* Members of the household is identified as destitute if household 
does not have access to safe drinking water, or safe water is more 
than 45 minute walk from home, round trip.*/
********************************************************************
gen	water_u = .
replace water_u = 1 if water==11 | water==12 | water==13 | water==14 | ///
					   water==21 | water==31 | water==41 | water==51 | ///
					   water==91
					   
replace water_u = 0 if water==32  | water==42 | water==61 | ///
					   water==71 | water==81 | water==96
					   
replace water_u = 0 if water_u==1 & timetowater>45 & timetowater!=. ///
					   & timetowater!=998
					   
replace water_u = . if water==99 | water==.

replace water_u = 0 if water==91 & ///
					   (ndwater==32 | ndwater==42 | ndwater==61 | ///
						ndwater==71 | ndwater==81 | ndwater==96)
						
lab var water_u "DST: HH has safe drinking water (considering distance)"
tab water water_u, miss


*** Harmonised MPI: MICS 2012 - MICS 2015/16 - MICS 2019 ***
/*Drinking water obtained from tanker truck and cart are 
harmonised as improved following the later survey. Bottled water is 
considered as an improved source of drinking water over time.*/
********************************************************************
gen	water_mdg_c = 1      if water<=31 | water==41 | water==51 | ///
							water==61 | water==71 | water==91						
replace water_mdg_c = 0 if  water==32 | water==42 | water==81 | water==96
						   
replace water_mdg_c = 0 if water_mdg_c==1 & timetowater >= 30 & ///
						   timetowater!=. & timetowater!=998
						 
replace water_mdg_c = . if water==. | water==99
lab var water_mdg_c "COT: HH has safe drinking water"
tab water water_mdg_c, miss


gen	water_u_c = .
replace water_u_c = 1 if water<=31 | water==41 | water==51 | ///
						 water==61 | water==71 | water==91		 
replace water_u_c = 0 if water==32 | water==42 | water==81 | water==96 
					   
replace water_u_c = 0 if water_u_c==1 & timetowater> 45 & ///
						 timetowater!=. & timetowater!=998
					 
replace water_u_c = . if water==. | water==99						
lab var water_u_c "COT-DST: HH has safe drinking water"
tab water water_u_c, miss


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
lab var floor_imp "HH has floor that it is not earth/sand/dung"
tab floor floor_imp, miss	


/* Members of the household are considered deprived if the household has wall 
made of natural or rudimentary materials */
clonevar wall = hc5
codebook wall, tab(99)
gen	wall_imp = 1 
replace wall_imp = 0 if wall<=26| wall==96 
replace wall_imp = . if wall==99 	
replace wall_imp = . if wall == .
lab var wall_imp "HH has wall that it is not of low quality materials"
tab wall wall_imp, miss	
	

/* Members of the household are considered deprived if the household has roof 
made of natural or rudimentary materials */
clonevar roof = hc4
codebook roof, tab(99)		
gen	roof_imp = 1 
replace roof_imp = 0 if roof<=23 |  roof==96 
replace roof_imp = . if roof== . 
lab var roof_imp "HH has roof that it is not of low quality materials"
tab roof roof_imp, miss


*** Standard MPI ***
/* Members of the household is deprived in housing if the roof, 
floor OR walls are constructed from low quality materials.*/
**************************************************************
gen housing_1 = 1
replace housing_1 = 0 if floor_imp==0 | wall_imp==0 | roof_imp==0
replace housing_1 = . if floor_imp==. & wall_imp==. & roof_imp==.
lab var housing_1 "HH has roof, floor & walls that it is not low quality material"
tab housing_1, miss


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
lab var housing_u "DST: HH has one of three (roof,floor/walls) that is not low quality material"
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

clonevar cookingfuel = hc6  
codebook cookingfuel, tab(99)


*** Standard MPI ***
/* Members of the household are considered deprived if the 
household uses solid fuels and solid biomass fuels for cooking. */
*****************************************************************
gen	cooking_mdg = 1
replace cooking_mdg = 0 if cookingfuel>5 & cookingfuel<95 
replace cooking_mdg = . if cookingfuel==. |cookingfuel==99
lab var cooking_mdg "HH has cooking fuel according to SDG standards"			 
tab cookingfuel cooking_mdg, miss	


*** Destitution MPI ***
*** (same as standard MPI) ***
****************************************
gen	cooking_u = cooking_mdg
lab var cooking_u "DST: HH uses clean fuels for cooking"



********************************************************************************
*** Step 2.10 Assets ownership ***
********************************************************************************

clonevar television = hc8n
replace television = 1 if hc8o==1
	/*Thailand MICS 2015-16: hc8n is television (plain monitor) and hc8o 
	is television (LCD/LED/Plasma monitor)*/ 
gen bw_television   = .
clonevar radio = hc8b 
clonevar telephone =  hc8d
clonevar mobiletelephone = hc9j
replace mobiletelephone = 1 if hc9k==1 
	/*Thailand MICS 2015-16: hc8d is non-mobile phone, hc9j is traditional 
	mobile telephone, and hc9k is smart phone. Both hc9j and hc9k have been 
	included in mobile telephone */
clonevar refrigerator = hc8e
clonevar car = hc9f  	
clonevar bicycle = hc9c
clonevar motorbike = hc9l
replace motorbike = 1 if hc9m==1
	/* Thailand MICS 2015-16: hc9l is motorcycle or scooter and hc9m is sport 
	motorcycle/big bike.*/		
clonevar computer = hc8i
replace computer=1 if computer!=1 & hc8j==1
	//Combine information on computer and tablet
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
tab hh_assets2, miss


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
gen psu = hh1
egen strata = group(hh7 hh6)	
label var psu "Primary sampling unit"
label var strata "Sample strata"

	//Retain year, month & date of interview:
desc hh5y hh5m hh5d 
clonevar year_interview = hh5y 	
clonevar month_interview = hh5m 
clonevar date_interview = hh5d 
 
 
	//Generate presence of subsample
gen subsample = .
	
 		
*** Keep main variables require for MPI calculation ***
keep hh_id ind_id subsample strata psu weight weight_ch sex age hhsize ///
area agec7 agec4 agec2 region headship marital_wom marital_men relationship ///
no_fem_eligible no_male_eligible child_eligible no_child_eligible ///
religion_wom religion_men religion_hh ethnic_wom ethnic_men ethnic_hh ///
insurance_wom insurance_men year_interview month_interview date_interview /// 
eduyears no_missing_edu hh_years_edu6 hh_years_edu_u ///
attendance child_schoolage no_missing_atten hh_child_atten hh_child_atten_u ///
underweight stunting wasting underweight_u stunting_u wasting_u ///
hh_no_underweight hh_no_stunting hh_no_wasting hh_no_uw_st ///
hh_no_underweight_u hh_no_stunting_u hh_no_wasting_u hh_no_uw_st_u ///
hh_nutrition_uw_st hh_nutrition_uw_st_u ///
child_mortality hh_mortality hh_mortality_u18_5y hh_mortality_u ///
electricity electricity_u toilet toilet_mdg shared_toilet toilet_u ///
water timetowater ndwater water_mdg water_u floor wall roof ///
floor_imp wall_imp roof_imp housing_1 housing_u ///
cookingfuel cooking_mdg cooking_u television radio telephone ///
refrigerator car bicycle motorbike animal_cart computer ///
n_small_assets2 hh_assets2 hh_assets2_u ///
water_mdg_c water_u_c


	 
*** Order file	***
order hh_id ind_id subsample strata psu weight weight_ch sex age hhsize ///
area agec7 agec4 agec2 region headship marital_wom marital_men relationship ///
no_fem_eligible no_male_eligible child_eligible no_child_eligible ///
religion_wom religion_men religion_hh ethnic_wom ethnic_men ethnic_hh ///
insurance_wom insurance_men year_interview month_interview date_interview /// 
eduyears no_missing_edu hh_years_edu6 hh_years_edu_u ///
attendance child_schoolage no_missing_atten hh_child_atten hh_child_atten_u ///
underweight stunting wasting underweight_u stunting_u wasting_u ///
hh_no_underweight hh_no_stunting hh_no_wasting hh_no_uw_st ///
hh_no_underweight_u hh_no_stunting_u hh_no_wasting_u hh_no_uw_st_u ///
hh_nutrition_uw_st hh_nutrition_uw_st_u ///
child_mortality hh_mortality hh_mortality_u18_5y hh_mortality_u ///
electricity electricity_u toilet toilet_mdg shared_toilet toilet_u ///
water timetowater ndwater water_mdg water_u floor wall roof ///
floor_imp wall_imp roof_imp housing_1 housing_u ///
cookingfuel cooking_mdg cooking_u television radio telephone ///
refrigerator car bicycle motorbike animal_cart computer ///
n_small_assets2 hh_assets2 hh_assets2_u ///
water_mdg_c water_u_c


*** Rename key global MPI indicators for estimation ***
recode hh_mortality			(0=1)(1=0) , gen(d_cm)
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
recode hh_mortality		    (0=1)(1=0) , gen(d_cm_01)
recode hh_nutrition_uw_st   (0=1)(1=0) , gen(d_nutr_01)
recode hh_child_atten 		(0=1)(1=0) , gen(d_satt_01)
recode hh_years_edu6 		(0=1)(1=0) , gen(d_educ_01)
recode electricity 			(0=1)(1=0) , gen(d_elct_01)
recode water_mdg_c 			(0=1)(1=0) , gen(d_wtr_01)
recode toilet_mdg 			(0=1)(1=0) , gen(d_sani_01)
recode housing_1 			(0=1)(1=0) , gen(d_hsg_01)
recode cooking_mdg 			(0=1)(1=0) , gen(d_ckfl_01)
recode hh_assets2 			(0=1)(1=0) , gen(d_asst_01)	
	

recode hh_mortality_u       (0=1)(1=0) , gen(dst_cm_01)
recode hh_nutrition_uw_st_u (0=1)(1=0) , gen(dst_nutr_01)
recode hh_child_atten_u 	(0=1)(1=0) , gen(dst_satt_01)
recode hh_years_edu_u 		(0=1)(1=0) , gen(dst_educ_01)
recode electricity_u		(0=1)(1=0) , gen(dst_elct_01)
recode water_u_c  	 		(0=1)(1=0) , gen(dst_wtr_01)
recode toilet_u 			(0=1)(1=0) , gen(dst_sani_01)
recode housing_u 			(0=1)(1=0) , gen(dst_hsg_01)
recode cooking_u			(0=1)(1=0) , gen(dst_ckfl_01)
recode hh_assets2_u 		(0=1)(1=0) , gen(dst_asst_01)


	/*In this survey, the harmonised 'region_01' variable is the 
	same as the standardised 'region' variable.*/	
clonevar region_01 = region 



char _dta[cty] "Thailand"
char _dta[ccty] "THA"
char _dta[year] "2015-2016" 	
char _dta[survey] "MICS"
char _dta[ccnum] "764"
char _dta[type] "micro"



sort ind_id
compress
la da "Micro data for `_dta[ccty]' (`_dta[ccnum]') from `c(current_date)' (`c(current_time)')."
save "$path_out/tha_mics15-16.dta", replace 

