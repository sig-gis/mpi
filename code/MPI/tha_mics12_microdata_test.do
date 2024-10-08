********************************************************************************
/*
Adapted from:
Oxford Poverty and Human Development Initiative (OPHI), University of Oxford. 
Global Multidimensional Poverty Index - Thailand MICS 2012 
[STATA do-file]. Available from OPHI website: http://ophi.org.uk/  

For further queries, contact: ophi@qeh.ox.ac.uk
*/
********************************************************************************

clear all 
set more off
*set maxvar 10000



cd "C:\Users\tianc\OneDrive\Documents\SIG\DISES\code\MPI"
global path_in "../../data/MICS/Thailand_MICS4_Datasets/Thailand_MICS4_Datasets/Thailand MICS 2012-13 SPSS Datasets" 
global path_out "../../data/MPI/tha_mics1213_test"
global path_ado "ado"
	
	

********************************************************************************
*** Step 1: Data preparation 
********************************************************************************
	
	
********************************************************************************
*** Step 1.1 CH - Children under 5 years
********************************************************************************

import spss using "$path_in/ch.sav", clear 

rename _all, lower	


gen double ind_id = hh1*1000000 + hh2*100 + ln 
format ind_id %20.0g


duplicates report ind_id


gen child_CH=1 



*** Variable: SEX ***
codebook hl4, tab (9) 
	//"1" for male ;"2" for female 
clonevar gender = hl4
tab gender


*** Variable: AGE ***
tab cage, miss
clonevar age_months = cage
replace age_months = . if cage==9999 
count if cage < 0 	
replace age_months = . if cage < 0 	
sum age_months

gen str6 ageunit = "months"
lab var ageunit "Months"



*** Variable: BODY WEIGHT (KILOGRAMS) ***
codebook an3, tab (9999) 
clonevar weight = an3	
replace weight = . if an3>=99 
	//All missing values or out of range are replaced as "."
tab	uf9 an3 if an3>=99 | an3==., miss   
sum weight	


*** Variable: HEIGHT (CENTIMETERS)
codebook an4, tab (9999) 
clonevar height = an4
replace height = . if an4>=999 
	//All missing values or out of range are replaced as "."
tab	uf9 an4 if an4>=999 | an4==., miss
sum height

	
*** Variable: MEASURED STANDING/LYING DOWN	
codebook an4a 
gen measure = "l" if an4a==1 
	//Child measured lying down
replace measure = "h" if an4a==2 
	//Child measured standing up
replace measure = " " if an4a==9 | an4a==.
	//Replace with " " if unknown
tab measure

	
*** Variable: OEDEMA ***
lookfor oedema œdème edema
gen str1 oedema = "n"  
	//This variable assumes no one has oedema


*** Variable: SAMPLING WEIGHT ***
	/* We don't require individual weight to compute the z-scores of a child. 
	So we assume all children in the sample have the same weight */
gen sw = 1	
sum sw


*** Indicate to STATA where the igrowup_restricted.ado file is stored:
	***Source of ado file: http://www.who.int/childgrowth/software/en/
adopath + "$path_ado/igrowup_stata"

*** We will now proceed to create three nutritional variables: 
	*** weight-for-age (underweight),  
	*** weight-for-height (wasting) 
	*** height-for-age (stunting)

*** We specify the first three parameters we need in order to use the ado file:
	*** reflib, 
	*** datalib, 
	*** datalab

/* We use 'reflib' to specify the package directory where the .dta files 
containing the WHO Child Growth Standards are stored. */	
gen str100 reflib = "$path_ado/igrowup_stata"
lab var reflib "Directory of reference tables"


/* We use datalib to specify the working directory where the input STATA 
dataset containing the anthropometric measurement is stored. */
gen str100 datalib = "$path_out" 
lab var datalib "Directory for datafiles"


/* We use datalab to specify the name that will prefix the output files that 
will be produced from using this ado file (datalab_z_r_rc and datalab_prev_rc)*/
gen str30 datalab = "children_nutri_tha"
lab var datalab "Working file"

	
/*We now run the command to calculate the z-scores with the adofile */
igrowup_restricted reflib datalib datalab gender age_months ageunit weight ///
height measure oedema sw


/*We now turn to using the dta file that was created and that contains 
the calculated z-scores to create the child nutrition variables following WHO 
standards */
use "$path_out/children_nutri_tha_z_rc.dta", clear 

		
*** Standard MPI indicator ***
	//Takes value 1 if the child is under 2 stdev below the median & 0 otherwise	
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


*** Destitution indicator  ***
	//Takes value 1 if the child is under 3 stdev below the median & 0 otherwise	
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
	/*Thailand MICS 2012: 129 children were replaced as missing because 
	they have extreme z-scores which are biologically implausible.*/
			
clonevar weight_ch = chweight
label var weight_ch "sample weight child under 5"	

		
	//Retain relevant variables:
keep ind_id child_CH ln weight_ch underweight* stunting* wasting*  
order ind_id child_CH ln weight_ch underweight* stunting* wasting*
sort ind_id
save "$path_out/THA12_CH.dta", replace
	
	
	

********************************************************************************
*** Step 1.2  BH - BIRTH RECODE 
*** (All females 15-49 years who ever gave birth)  
********************************************************************************

	/* Note: There is no BH data file for Thailand MICS 2012. Hence this 
	section has been deactivated */

	
********************************************************************************
*** Step 1.3  WM - WOMEN's RECODE  
*** (Eligible females 15-49 years in the household)
********************************************************************************
/*The purpose of step 1.3 is to identify all deaths that are reported by 
eligible women.*/

import spss using "$path_in/wm.sav", clear 
	
rename _all, lower	

	
*** Generate individual unique key variable required for data merging using:
	*** hh1=cluster number; 
	*** hh2=household number; 
	*** wm4=women's line number.  
gen double ind_id = hh1*1000000 + hh2*100 + wm4 
format ind_id %20.0g
label var ind_id "Individual ID"

duplicates report ind_id

gen women_WM =1 
	//Identification variable for observations in WM recode

	
tab wb2 wm7, miss
	/*Thailand MICS 2012: 21,981 women 15-49 years were successfully 
	interviewed.*/
	
	
	//Retain relevant variables:		
gen religion_wom = .
lab var religion_wom "Women's religion"	

gen ethnic_wom = .
lab var ethnic_wom "Women's ethnicity"	

gen insurance_wom = .
label var insurance_wom "Women have health insurance"	

	
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
replace mstatus = . if mstatus==9	
label define lab_mar 1"never married" 2"currently married" 3"widowed" ///
4"divorced" 5"not living together"
label values marital lab_mar	
label var marital "Marital status of household member"
tab marital, miss
tab ma6 marital, miss
tab mstatus marital, miss
rename marital marital_wom	

	
keep wm7* cm1 cm8 cm9a cm9b ind_id women_WM *_wom
order wm7* cm1 cm8 cm9a cm9b ind_id women_WM *_wom
sort ind_id
save "$path_out/THA12_WM.dta", replace


********************************************************************************
*** Step 1.4  MN - MEN'S RECODE 
***(Eligible man: 15-59 years in the household) 
********************************************************************************

	/* Note: There is no MN data file for Thailand MICS 2012. Hence this 
	section has been deactivated */

********************************************************************************
*** Step 1.5 HH - HOUSEHOLD RECODE 
***(All households interviewed) 
********************************************************************************

import spss using "$path_in/hh.sav", clear 
	
rename _all, lower	


*** Generate individual unique key variable required for data merging
	*** hh1=cluster number;  
	*** hh2=household number 
gen	double hh_id = hh1*1000 + hh2 
format	hh_id %20.0g
lab var hh_id "Household ID"


duplicates report hh_id 
save "$path_out/THA12_HH.dta", replace

	
********************************************************************************
*** Step 1.6 HL - HOUSEHOLD MEMBER  
********************************************************************************

import spss "$path_in/hl.sav", clear 

rename _all, lower

	
*** Generate a household unique key variable at the household level using: 
	***hh1=cluster number 
	***hh2=household number
gen double hh_id = hh1*1000 + hh2 
format hh_id %20.0g
label var hh_id "Household ID"


*** Generate individual unique key variable required for data merging using:
	*** hh1=cluster number; 
	*** hh2=household number; 
	*** hl1=respondent's line number.
gen double ind_id = hh1*1000000 + hh2*100 + hl1 
format ind_id %20.0g
label var ind_id "Individual ID"

duplicates report ind_id 


sort ind_id


********************************************************************************
*** Step 1.7 DATA MERGING 
******************************************************************************** 

 
*** Merging WM Recode 
*****************************************
merge 1:1 ind_id using "$path_out/THA12_WM.dta"
count if hl7>0
drop _merge	


*** Merging HH Recode 
*****************************************
merge m:1 hh_id using "$path_out/THA12_HH.dta"
tab hh9 if _m==2
drop  if _merge==2
	//Drop households that were not interviewed 
drop _merge


*** Merging MN Recode 
*****************************************
gen religion_men = . 
lab var religion_men "Men's religion"		

gen ethnic_men = .
lab var ethnic_men "Men's ethnicity"
	
gen insurance_men = .
label var insurance_men "Men have health insurance"	

gen marital_men = .
label var marital_men "Marital status of household member"


*** Merging CH Recode 
*****************************************
merge 1:1 ind_id using "$path_out/THA12_CH.dta"
drop _merge


sort ind_id


********************************************************************************
*** Step 1.8 CONTROL VARIABLES
********************************************************************************

*** No eligible women 15-49 years 
*** for child mortality indicator
*****************************************
gen	fem_eligible = (women_WM==1)
bys	hh_id: egen hh_n_fem_eligible = sum(fem_eligible) 	
	//Number of eligible women for interview in the hh
gen	no_fem_eligible = (hh_n_fem_eligible==0) 									
	//Takes value 1 if the household had no eligible females for an interview
lab var no_fem_eligible "Household has no eligible women"
drop hh_n_fem_eligible 
tab no_fem_eligible, miss


*** No eligible men 15-49 years
*** for child mortality indicator (if relevant)
*****************************************
gen	no_male_eligible = .
lab var no_male_eligible "Household has no eligible man for interview"
tab no_male_eligible, miss

	
*** No eligible children under 5
*** for child nutrition indicator
*****************************************
count if child_CH==1
count if hl9>0 & hl9!=.
gen	child_eligible = (child_CH==1) 
bysort	hh_id: egen hh_n_children_eligible = sum(child_eligible)  
	//Number of eligible children for anthropometrics
gen	no_child_eligible = (hh_n_children_eligible==0) 
	//Takes value 1 if there were no eligible children for anthropometrics
lab var no_child_eligible "Household has no children eligible for anthropometric"
drop hh_n_children_eligible
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
codebook hh6, tab (5)	
	//Municipal==urban; Non-municipal==rural	
clonevar area = hh6  
replace area=0 if area==2 | area==3 
label define lab_area 1 "urban" 0 "rural"
label values area lab_area
label var area "Area: urban-rural"


//Relationship to the head of household
clonevar relationship = hl3 
codebook relationship, tab (20)
recode relationship (1=1)(2=2)(3 13=3)(4/12=4)(14=5)(98=.)
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
label var age "Age of household member"


//Age group (for global MPI estimation)
recode age (0/4 = 1 "0-4")(5/9 = 2 "5-9")(10/14 = 3 "10-14") ///
		   (15/17 = 4 "15-17")(18/59 = 5 "18-59")(60/max=6 "60+"), gen(agec7)
lab var agec7 "age groups (7 groups)"	
	   
recode age (0/9 = 1 "0-9") (10/17 = 2 "10-17")(18/59 = 3 "18-59") ///
		   (60/max=4 "60+") , gen(agec4)
lab var agec4 "age groups (4 groups)"

recode age (0/17 = 1 "0-17") (18/max = 2 "18+"), gen(agec2)		 		   
lab var agec2 "age groups (2 groups)"


//Total number of de jure hh members in the household
gen member = 1
bysort hh_id: egen hhsize = sum(member)
label var hhsize "Household size"
tab hhsize, miss
compare hhsize hh11
	//1 observation missing in hh11 but the rest match.
drop member


//Religion of the household head
gen religion_hh = hc1a
label var religion_hh "Religion of household head"
codebook religion_hh, tab (99)

//Ethnicity of the household head
gen ethnic_hh = ethnicity
label var ethnic_hh "Ethnicity of household head"
codebook ethnic_hh, tab (99)


//Subnational region
	/*The sample for the Thailand MICS 2012 was designed to provide 
	estimates for a large number of indicators on the situation of children and 
	women at the national level, for urban and rural areas, and for Bangkok and 
	four regions: Central, North, Northeast and South (p.9).*/   	
codebook hh7, tab (99) 
clonevar region = hh7
lab var region "Region for subnational decomposition"
codebook region, tab (99)
label define reg_lab 1 "Bangkok" 2 "Central" 3 "North" 4 "Northeast" 5 "South"
label values region reg_lab
codebook region, tab (999)


********************************************************************************
***  Step 2 Data preparation  ***
***  Standardization of the 10 Global MPI indicators 
***  Identification of non-deprived & deprived individuals  
********************************************************************************

********************************************************************************
*** Step 2.1 Years of Schooling ***
********************************************************************************

	/*In Thailand, children enter primary school at age 6 and enter 
	secondary school at age 12. There are 6 grades in primary school 
	and 6 grades in secondary school (p.93)*/

codebook ed4a, tab (99)
clonevar edulevel = ed4a 
	//Highest educational level attended
replace edulevel = . if ed4a==. | ed4a==98 
	//All missing values or out of range are replaced as "."
replace edulevel = 0 if ed3==2 
	//Those who never attended school are replaced as '0'
label var edulevel "Highest level of education attended"


codebook ed4b, tab (99)
clonevar eduhighyear = ed4b 
	//Highest grade attended at that level
replace eduhighyear = .  if ed4b==. | ed4b==98
	//All missing values or out of range are replaced as "."
replace eduhighyear = 0  if ed3==2 
	//Those who never attended school are replaced as '0'
lab var eduhighyear "Highest grade attended for each level of edu"


*** Cleaning inconsistencies
replace edulevel = 0 if age<10  
replace eduhighyear = 0 if age<10 
	/*At this point, we disregard the years of education of household members 
	younger than 10 years by replacing the relevant variables with '0 years' 
	since they are too young to have completed 6 years of schooling.*/ 
replace eduhighyear = 0 if edulevel<1
	//Early childhood education has no grade

	
*** Now we create the years of schooling variable
tab eduhighyear edulevel, miss
gen	eduyears = eduhighyear
replace eduyears = eduhighyear + 6 if (edulevel==2 | edulevel==3)
replace eduyears = 6 if edulevel==2 & eduhighyear==.
	/*Lower secondary education assumed to start after 6 years of primary 
	education; and after 9 years they start upper secondary.*/
replace eduyears = 9 if edulevel==3	& eduhighyear==0
replace eduyears = 9 if edulevel==3 & eduhighyear==.
	//Completed lower secondary despite not having grade  	
replace eduyears = eduhighyear + 9 if edulevel==4 
replace eduyears = 9 if edulevel==4 & eduhighyear==. 
	//Technical education assumed to start after 9 years of general education 
replace eduyears = eduhighyear + 12 if (edulevel==5 | edulevel==6) 
replace eduyears = 12 if (edulevel==5 & eduhighyear==.) | (edulevel==6 & eduhighyear==.) 
	//Diploma or bachelors after 12 years of education. 
replace eduyears = eduhighyear + 16 if edulevel==7
	//Masters after 12 years of education and 4 years of bachelors.
replace eduyears = eduhighyear + 18 if edulevel==8
replace eduyears = 18 if edulevel==8 & eduhighyear==. 
	//PhD after 12 years of education, 4 years of bachelors and 2 years of masters.
tab eduyears, miss
tab eduyears edulevel, miss	

	
*** Checking for further inconsistencies 
replace eduyears = . if age<=eduyears & age>0 
	/*There are cases in which the years of schooling are greater than the 
	age of the individual. This is clearly a mistake in the data.*/
replace eduyears = 0 if age< 10
replace eduyears = 0 if (age==10 | age==11) & eduyears < 6 
	/*The variable "eduyears" was replaced with a '0' for ineligible household 
	members, i.e.: those who have not completed 6 years of schooling following 
	their starting school age */
lab var eduyears "Total number of years of education accomplished"
tab eduyears, miss


	/*A control variable is created on whether there is information on 
	years of education for at least 2/3 of the eligible household members*/	
gen temp = 1 if eduyears!=. & age>=12 & age!=.
replace temp = 1 if age==10 & eduyears>=6 & eduyears<.
replace temp = 1 if age==11 & eduyears>=6 & eduyears<.
bysort	hh_id: egen no_missing_edu = sum(temp)	
	//Total eligible household members with no missing years of education
gen temp2 = 1 if age>=12 & age!=.
replace temp2 = 1 if age==10 & eduyears>=6 & eduyears<.
replace temp2 = 1 if age==11 & eduyears>=6 & eduyears<.
bysort hh_id: egen hhs = sum(temp2)
	/*Total number of eligible household members who should have information 
	on years of education */
replace no_missing_edu = no_missing_edu/hhs
replace no_missing_edu = (no_missing_edu>=2/3)
	/*Identify whether there is information on years of education for at 
	least 2/3 of the eligible household members */
tab no_missing_edu, miss
	//The value for 0 (missing) is 0.17% 
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
tab hh_years_edu6 [aw = weight], miss 

	
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
	
gen	attendance = .
replace attendance = 1 if ed5==1 
	//Replace attendance with '1' if currently attending school	
replace attendance = 0 if ed5==2 
	//Replace attendance with '0' if currently not attending school	
replace attendance = 0 if ed3==2 
	//Replace attendance with '0' if never ever attended school		
replace attendance = 0 if age<5 | age>24 
	//Replace attendance with '0' for individuals who are not of school age	
label define lab_attend 1 "currently attending" 0 "not currently attending"
label values attendance lab_attend
label var attendance "Attended school during current school year"	
tab attendance, miss


*** Standard MPI ***
/*The entire household is considered deprived if any 
school-aged child is not attending school up to class 8.*/ 
******************************************************************* 
gen	child_schoolage = (age>=6 & age<=14)
	/*In Thailand, the official school entrance age is 6 years (p.93)   
	   So, age range is 6-14 (=6+8)*/

	
	/*A control variable is created on whether there is no information on 
	school attendance for at least 2/3 of the school age children */
count if child_schoolage==1 & attendance==.
	/*How many eligible school aged children with missing school 
	attendance?: 0 children */
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
label var no_missing_atten "No missing school attendance for at least 2/3 of the school aged children"		
drop temp temp2 hhs
		
bysort hh_id: egen hh_children_schoolage = sum(child_schoolage)
replace hh_children_schoolage = (hh_children_schoolage>0) 
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
/*The entire household is considered deprived if any 
school-aged child is not attending school up to class 6.*/ 
******************************************************************* 
gen	child_schoolage_6 = (age>=6 & age<=12) 
	/*In Thailand, the official school entrance age is 6 years  
	  So, age range is 6-12 (=6+6) */

	
	/*A control variable is created on whether there is no information on 
	school attendance for at least 2/3 of the children attending school up to 
	class 6 */	
count if child_schoolage_6==1 & attendance==.	
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
 
********************************************************************************
*** Step 2.3a Child Nutrition ***
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
tab hh_no_uw_st, m


*** Destitution MPI  ***
gen hh_no_uw_st_u = 1 if hh_no_stunting_u==1 & hh_no_underweight_u==1
replace hh_no_uw_st_u = 0 if hh_no_stunting_u==0 | hh_no_underweight_u==0
replace hh_no_uw_st_u = . if hh_no_stunting_u==. & hh_no_underweight_u==.
replace hh_no_uw_st_u = 1 if no_child_eligible==1 
lab var hh_no_uw_st_u "Destitute: Household has no child underweight or stunted"


********************************************************************************
*** Step 2.3b Household Nutrition Indicator ***
********************************************************************************

*** Standard MPI ***
/* The indicator takes value 1 if the household has no child under 5 who 
has either height-for-age or weight-for-age that is under 2 stdev below 
the median. It also takes value 1 for the households that have no eligible 
children. The indicator takes a value of missing only if all eligible 
children have missing information in their respective nutrition variable. */
************************************************************************
gen	hh_nutrition_uw_st = 1
replace hh_nutrition_uw_st = 0 if hh_no_uw_st==0
replace hh_nutrition_uw_st = . if hh_no_uw_st==.
replace hh_nutrition_uw_st = 1 if no_child_eligible==1   		
lab var hh_nutrition_uw_st "Household has no individuals malnourished"
tab hh_nutrition_uw_st, miss


*** Destitution MPI ***
/* The indicator takes value 1 if the household has no child under 5 who 
has either height-for-age or weight-for-age that is under 2 stdev below 
the median. It also takes value 1 for the households that have no eligible 
children. The indicator takes a value of missing only if all eligible 
children have missing information in their respective nutrition variable. */
************************************************************************
gen	hh_nutrition_uw_st_u = 1
replace hh_nutrition_uw_st_u = 0 if hh_no_uw_st_u==0
replace hh_nutrition_uw_st_u = . if hh_no_uw_st_u==.
replace hh_nutrition_uw_st_u = 1 if no_child_eligible==1   		
lab var hh_nutrition_uw_st_u "Household has no individuals malnourished (destitution)"
tab hh_nutrition_uw_st_u, miss


********************************************************************************
*** Step 2.4 Child Mortality ***
********************************************************************************

codebook cm9a cm9b
	/*cm9: number of sons who have died 
	  cm10: number of daughters who have died */
	  
	  
tab cm1 cm8, miss
	/*Identify the number of women who never gave birth 
	but has information on child mortality: 4 women.
	We make use of the birth history information from
	these women.*/	  
	  
	  
egen temp_f = rowtotal(cm9a cm9b), missing
	//Total child mortality reported by eligible women
replace temp_f = 0 if (cm1==1 & cm8==2) | (cm1==2 & cm8==2) 
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
tab child_mortality_m, miss


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
replace hh_mortality = . if child_mortality==.
replace hh_mortality = 1 if no_fem_eligible==1	
lab var hh_mortality "Household had no child mortality"
tab hh_mortality, miss


gen hh_mortality_u18_5y = .
lab var hh_mortality_u18_5y "Household had no under 18 child mortality in the last 5 years"


*** Destitution MPI *** 
*** (same as standard MPI) ***
************************************************************************
gen hh_mortality_u = hh_mortality	
lab var hh_mortality_u "Household had no child mortality"

				
********************************************************************************
*** Step 2.5 Electricity ***
********************************************************************************

*** Standard MPI ***
/*Members of the household are considered 
deprived if the household has no electricity */
****************************************
clonevar electricity = hc8a
codebook electricity, tab (9)
replace electricity = 0 if electricity==2
	//0=no; 1=yes 
replace electricity = . if electricity==9 
	//Replace missing values 
label define lab_elec 1 "have electricity" 0 "no electricity"
label values electricity lab_elec		
label var electricity "Household has electricity"
tab electricity, miss


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
desc ws9 ws8  
clonevar toilet = ws8  
clonevar shared_toilet = ws9 
codebook shared_toilet, tab(99)  
recode shared_toilet (2=0)

		
*** Standard MPI ***
/*Members of the household are considered deprived if the household's 
sanitation facility is not improved (according to the SDG guideline) 
or it is improved but shared with other households*/
********************************************************************
codebook toilet, tab(99)
gen	toilet_mdg = (toilet<=22 & shared_toilet!=1) 	
replace toilet_mdg = 0 if (toilet<=22)  & shared_toilet==1 	
replace toilet_mdg = 0 if toilet==14 		
replace toilet_mdg = . if toilet==.
lab var toilet_mdg "Household has improved sanitation"
tab toilet_mdg, miss
	

*** Destitution MPI ***
/*Members of the household are considered deprived if household practises 
open defecation or uses other unidentifiable sanitation practises */
********************************************************************
gen	toilet_u = .
replace toilet_u = 0 if toilet==95 | toilet==96 
replace toilet_u = 1 if toilet!=95 & toilet!=96 & toilet!=.
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
gen	water_mdg = 1 if     water<=31 | water==41 | water==51 | water==91 	 	
replace water_mdg = 0 if water==32 | water==42 | water==61 | ///
						 water==71 | water==81 | water==96 
						 
codebook timetowater, tab(999)		
replace water_mdg = 0 if water_mdg==1 & timetowater >= 30 & timetowater!=. & ///
						 timetowater!=998	  	
replace water_mdg = . if water==.
	
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
replace water_u = 1 if  water<=31 | water==41 | water==51 | water==91  				   
replace water_u = 0 if  water==32 | water==42 | water==61 | ///
						water==71 | water==81 | water==96
						
replace water_u = 0 if water_u==1 & timetowater> 45 & timetowater!=. ///
					   & timetowater!=998						   
replace water_u = . if water==.

replace water_u = 0 if  water==91 & ///
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
replace floor_imp = 0 if floor==11 | floor==96 	
replace floor_imp = . if floor==. | floor==99
lab var floor_imp "Household has floor that it is not earth/sand/dung"
tab floor floor_imp, miss	


/* Members of the household are considered deprived if the household has walls 
made of natural or rudimentary materials. We followed the report's definitions
of natural or rudimentary materials. */
clonevar wall = hc5
codebook wall, tab(99)
gen	wall_imp = 1 
replace wall_imp = 0 if wall<=26 | wall==96 	
replace wall_imp = . if wall==. | wall==99	
lab var wall_imp "Household has wall that it is not of low quality materials"
tab wall wall_imp, miss	

		
/* Members of the household are considered deprived if the household has roof 
made of natural or rudimentary materials. We followed the report's definitions
of natural and rudimentary materials. */
clonevar roof = hc4
codebook roof, tab(99)	
gen	roof_imp = 1 
replace roof_imp = 0 if roof<=24 | roof==96	
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

lookfor cooking combustible
clonevar cookingfuel = hc6 
	//eu4 = type of fuel or energy source used for the cookstove

	
*** Standard MPI ***
/* Members of the household are considered deprived if the 
household uses solid fuels and solid biomass fuels for cooking. */
*****************************************************************
codebook cookingfuel, tab(99)
gen	cooking_mdg = 1
replace cooking_mdg = 0 if cookingfuel>5 & cookingfuel<95 
replace cooking_mdg = . if cookingfuel==. |cookingfuel==99
lab var cooking_mdg "Household cooks with clean fuels"	
tab cookingfuel cooking_mdg, miss


*** Destitution MPI ***
*** (same as standard MPI) ***
****************************************	
gen	cooking_u = cooking_mdg
lab var cooking_u "Household cooks with clean fuels"


********************************************************************************
*** Step 2.10 Assets ownership ***
********************************************************************************

*** Television/LCD TV/plasma TV/color TV/black & white tv
lookfor tv television plasma lcd télé
codebook hc8c1 hc8c2
clonevar television = hc8c1
replace television=1 if television!=1 & hc8c2==1	
	//Combine information on plain monitor and LCD/LED/Plasma monitor.
tab hc8c1 hc8c2 if television==1,miss
lab var television "Household has television"

		
***	Radio/walkman/stereo/kindle
lookfor radio walkman stereo stéréo
codebook hc8b
clonevar radio = hc8b 
lab var radio "Household has radio"	


***	Handphone/telephone/iphone/mobilephone/ipod
lookfor telephone téléphone mobilephone ipod phone
codebook hc8d hc9b
clonevar telephone =  hc8d
replace telephone=1 if telephone!=1 & hc9b==1	
	//hc12=mobilephone. Combine information on telephone and mobilephone.	
tab hc8d hc9b if telephone==1,miss
lab var telephone "Household has telephone (landline/mobilephone)"	

	
***	Refrigerator/icebox/fridge
lookfor refrigerator réfrigérateur
codebook hc8e
clonevar refrigerator = hc8e 
lab var refrigerator "Household has refrigerator"


***	Car/van/lorry/truck
lookfor car voiture truck van
codebook hc9f
clonevar car = hc9f 
lab var car "Household has car"		

	
***	Bicycle/cycle rickshaw
lookfor bicycle bicyclette
codebook hc9c
clonevar bicycle = hc9c 
lab var bicycle "Household has bicycle"	
	
	
***	Motorbike/motorized bike/autorickshaw
lookfor motorbike moto
codebook hc9d	
clonevar motorbike = hc9d
lab var motorbike "Household has motorbike"

	
***	Computer/laptop/tablet
lookfor computer ordinateur laptop ipad tablet
codebook hc8i
clonevar computer = hc8i
lab var computer "Household has computer"


***	Animal cart
lookfor brouette charrette cart
codebook hc9e
clonevar animal_cart = hc9e
lab var animal_cart "Household has animal cart"	

 
foreach var in television radio telephone refrigerator car ///
			   bicycle motorbike computer animal_cart {
replace `var' = 0 if `var'==2 
label define lab_`var' 0"No" 1"Yes"
label values `var' lab_`var'			   
replace `var' = . if `var'==9 | `var'==99 | `var'==8 | `var'==98 
}
	//Labels defined and missing values replaced	
	


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



*** Harmonised MPI *** 
************************************************************************
	/*In the case of Thailand, there is no information on animal cart in 
	the later surveys, namely MICS 2015-16 and MICS 2019. As such, in 
	the harmonised MPI, this indicator is excluded from the household assets.*/

gen animal_cart_c = .
lab var animal_cart_c "Household has animal cart"	
	
egen n_small_assets2_c = rowtotal(television radio telephone refrigerator bicycle motorbike computer), missing
lab var n_small_assets2_c "COT:Household Number of Small Assets Owned" 
   
gen hh_assets2_c = (car==1 | n_small_assets2_c > 1) 
replace hh_assets2_c = . if car==. & n_small_assets2_c==.
lab var hh_assets2_c "COT Asset Ownership: HH has car or more than 1 small assets incl computer & animal cart"
tab hh_assets2_c, miss

gen	hh_assets2_u_c = (car==1 | n_small_assets2_c>0)
replace hh_assets2_u_c = . if car==. & n_small_assets2_c==.
lab var hh_assets2_u_c "COT Asset Ownership: HH has car or at least 1 small assets incl computer & animal cart"


********************************************************************************
*** Step 2.11 Rename and keep variables for MPI calculation 
********************************************************************************
	

	//Retain data on sampling design: 
desc psu stratum
clonevar strata = stratum
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
water_mdg_c water_u_c hh_assets2_c hh_assets2_u_c

	 
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
water_mdg_c water_u_c hh_assets2_c hh_assets2_u_c



*** Rename key global MPI indicators for estimation ***
recode hh_mortality         (0=1)(1=0) , gen(d_cm)
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
recode hh_mortality			(0=1)(1=0) , gen(d_cm_01)
recode hh_nutrition_uw_st 	(0=1)(1=0) , gen(d_nutr_01)
recode hh_child_atten 		(0=1)(1=0) , gen(d_satt_01)
recode hh_years_edu6 		(0=1)(1=0) , gen(d_educ_01)
recode electricity 			(0=1)(1=0) , gen(d_elct_01)
recode water_mdg_c 			(0=1)(1=0) , gen(d_wtr_01)
recode toilet_mdg 			(0=1)(1=0) , gen(d_sani_01)
recode housing_1 			(0=1)(1=0) , gen(d_hsg_01)
recode cooking_mdg 			(0=1)(1=0) , gen(d_ckfl_01)
recode hh_assets2_c 		(0=1)(1=0) , gen(d_asst_01)	
	

recode hh_mortality_u       (0=1)(1=0) , gen(dst_cm_01)
recode hh_nutrition_uw_st_u (0=1)(1=0) , gen(dst_nutr_01)
recode hh_child_atten_u 	(0=1)(1=0) , gen(dst_satt_01)
recode hh_years_edu_u 		(0=1)(1=0) , gen(dst_educ_01)
recode electricity_u		(0=1)(1=0) , gen(dst_elct_01)
recode water_u_c	 		(0=1)(1=0) , gen(dst_wtr_01)
recode toilet_u 			(0=1)(1=0) , gen(dst_sani_01)
recode housing_u 			(0=1)(1=0) , gen(dst_hsg_01)
recode cooking_u			(0=1)(1=0) , gen(dst_ckfl_01)
recode hh_assets2_u_c 		(0=1)(1=0) , gen(dst_asst_01)
 	
 
	/*In this survey, the harmonised 'region_01' variable is the 
	same as the standardised 'region' variable.*/	
clonevar region_01 = region 



char _dta[cty] "Thailand"
char _dta[ccty] "THA"
char _dta[year] "2012" 	
char _dta[survey] "MICS"
char _dta[ccnum] "764"
char _dta[type] "micro"

	

sort ind_id
compress
la da "Micro data for `_dta[ccty]' (`_dta[ccnum]') from `c(current_date)' (`c(current_time)')."
save "$path_out/tha_mics12.dta", replace 
