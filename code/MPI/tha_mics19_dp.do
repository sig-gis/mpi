********************************************************************************
/*
Adapted from:
Oxford Poverty and Human Development Initiative (OPHI), University of Oxford. 
Global Multidimensional Poverty Index - Thailand MICS 2019 
[STATA do-file]. Available from OPHI website: http://ophi.org.uk/  

For further queries, contact: ophi@qeh.ox.ac.uk
*/
********************************************************************************

clear all 
set more off


cd "C:\Users\tianc\OneDrive\Documents\SIG\DISES\code\MPI"
global path_in "../../data/MICS/Thailand MICS6 and Thailand Selected 17 Provinces MICS6 Datasets/Thailand MICS6 Datasets/Thailand MICS6 Datasets/Thailand MICS6 SPSS Datasets" 	
// global path_in "../../data/MICS/Thailand MICS6 and Thailand Selected 17 Provinces MICS6 Datasets/Thailand Selected 17 Provinces MICS6 Datasets/Thailand Selected 17 Provinces MICS6 Datasets" 	
global path_out "../../data/MPI/tha_mics19_test"
global path_ado "ado"

	

********************************************************************************
*** Step 1: Data preparation 
********************************************************************************
	

********************************************************************************
*** Step 1.1 CH - Children under 5 years
********************************************************************************

import spss using "$path_in/ch.sav", clear

rename _all, lower

		

gen double ind_id = hh1*10000 + hh2*100 + ln 
format ind_id %20.0g

codebook ind_id
duplicates report ind_id
 

gen child_CH=1 

	
*** Variable: SEX ***
codebook hl4, tab (9) 
	//"1" for male ;"2" for female 
clonevar gender = hl4
tab gender


*** Variable: AGE ***
desc cage caged
tab cage, miss
	//Age in months: information missing for 192 children (1.38%)
tab caged, miss
	/*Age in days: information missing for 197 children (1.42%).
	Since the difference is minimal, it is best to use age in days as it 
	result in more accurate anthropometric measures. */
sum cage if caged>9000
clonevar age_days = caged
replace age_days = trunc(cage*(365/12)) if age_days>=9000 & cage<9000
sum age_days 
	//13,689 is the same number that appears in the report (p.ix)
gen str6 ageunit = "days"
lab var ageunit "Days"
	

*** Variable: BODY WEIGHT (KILOGRAMS) ***
codebook an8, tab (9999) 
clonevar weight = an8	
replace weight = . if an8>=99 
	//All missing values or out of range are replaced as "."
tab	uf17 an8 if an8>=99 | an8==., miss   
sum weight 	


*** Variable: HEIGHT (CENTIMETERS)
codebook an11, tab (9999) 
clonevar height = an11
replace height = . if an11>=999 
	//All missing values or out of range are replaced as "."
tab	uf17 an11 if an11>=999 | an11==., miss
sum height 

	
*** Variable: MEASURED STANDING/LYING DOWN	
codebook an12  
gen measure = "l" if an12==1 
	//Child measured lying down
replace measure = "h" if an12==2 
	//Child measured standing up
replace measure = " " if an12==9 | an12==0 | an12==. 
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
igrowup_restricted reflib datalib datalab gender age_days ageunit weight ///
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
	/*Thailand MICS 2019: 318 children were replaced as missing because 
	they have extreme z-scores which are biologically implausible. */
	
count  
	/*Thailand MICS 2019: the number of eligible children is 13,881 as in 
	the country report (p.ix). */
	
	
clonevar weight_ch = chweight
label var weight_ch "sample weight child under 5"	
	
	
	//Retain relevant variables:
keep ind_id child_CH ln weight_ch underweight* stunting* wasting*  
order ind_id child_CH ln weight_ch underweight* stunting* wasting*
sort ind_id
save "$path_out/THA19_CH.dta", replace


	
********************************************************************************
*** Step 1.2  BH - BIRTH RECODE 
*** (All females 15-49 years who ever gave birth)  
********************************************************************************
	/* Note: There is no BH data file for Thailand MICS 2019. Hence this 
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
	*** wm3=women's line number.  
gen double ind_id = hh1*10000 + hh2*100 + wm3
format ind_id %20.0g
label var ind_id "Individual ID"

duplicates report ind_id 

gen women_WM=1 
	//Identification variable for observations in WM recode

	
tab wb4 wm17, miss
	/*Thailand MICS 2019: 25,087 women 15-49 years were successfully 
	interviewed. Matches report (p.ix).*/	
	
tab cm1 cm8, miss	
	/* Thailand MICS 2019: 10 women report never having 
	given birth but has given birth to a boy or girl who was born alive 
	but later died. We use the child mortality information provided by 
	these individuals in section 2.4.*/	
	
	//Retain relevant variables:	
gen religion_wom = .	
lab var religion_wom "Women's religion"	

gen ethnic_wom = .
lab var ethnic_wom "Women's ethnicity"	

clonevar insurance_wom = wb18 
label var insurance_wom "Women have health insurance"	

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
replace marital = 4 if mstatus == 9 & ma6==2
	//4: Divorced	
replace marital = 5 if mstatus == 2 & ma6==3
replace marital = 5 if mstatus == 9 & ma6==3
replace marital = 5 if mstatus == 2 & ma6==9
	//5: Separated/not living together
label define lab_mar 1"never married" 2"currently married" 3"widowed" ///
4"divorced" 5"not living together"
label values marital lab_mar	
label var marital "Marital status of household member"
tab marital, miss
tab ma6 marital, miss
tab mstatus marital, miss
rename marital marital_wom	

	
keep wm7* cm1 cm8 cm9 cm10 ind_id women_WM *_wom
order wm7* cm1 cm8 cm9 cm10 ind_id women_WM *_wom
sort ind_id
save "$path_out/THA19_WM.dta", replace
 
	

********************************************************************************
*** Step 1.4  MN - MEN'S RECODE 
***(Eligible man: 15-59 years in the household) 
********************************************************************************
/*The purpose of step 1.4 is to identify all deaths that are reported by 
eligible men.*/

import spss using "$path_in/mn.sav", clear 

rename _all, lower

	
*** Generate individual unique key variable required for data merging using:
	*** hh1=cluster number; 
	*** hh2=household number; 
	*** ln=respondent's line number.  
gen double ind_id = hh1*10000 + hh2*100 + ln 
format ind_id %20.0g
label var ind_id "Individual ID"	
	
duplicates report ind_id 

gen men_MN=1 	
	//Identification variable for observations in MR recode

	
tab mwb4 mwm17, miss 
	/*Thailand MICS 2019: 11,023 men 15-49 years were successfully 
	interviewed. Matches report (p.ix).*/
	
tab mcm1 mcm8, miss
	/*Thailand MICS 2019: 9 men report not having a child but 
	have fathered a son or daughter who was born alive but 
	later died. We use the child mortality information provided 
	by these individuals in section 2.4. */


	//Retain relevant variables:
gen religion_men = . 	
lab var religion_men "Men's religion"	


gen ethnic_men = .
lab var ethnic_men "Men's ethnicity"


clonevar insurance_men = mwb18
label var insurance_men "Men have health insurance"	


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
replace marital = 5 if mmstatus == 2 & mma6==9
	//5: Separated/not living together	
label define lab_mar 1"never married" 2"currently married" 3"widowed" ///
4"divorced" 5"not living together"
label values marital lab_mar	
label var marital "Marital status of household member"
tab marital, miss
tab mma6 marital, miss
tab mmstatus marital, miss
rename marital marital_men
	
keep mcm1 mcm8 mcm9 mcm10 ind_id men_MN *_men 
order mcm1 mcm8 mcm9 mcm10 ind_id men_MN *_men 
sort ind_id
save "$path_out/THA19_MN.dta", replace

	
********************************************************************************
*** Step 1.5 HH - HOUSEHOLD RECODE 
***(All households interviewed) 
********************************************************************************

import spss using "$path_in/hh.sav", clear 
	
rename _all, lower	

*** Generate individual unique key variable required for data merging
	*** hh1=cluster number;  
	*** hh2=household number 
gen	double hh_id = hh1*100 + hh2 
format	hh_id %20.0g
lab var hh_id "Household ID"

duplicates report hh_id 

save "$path_out/THA19_HH.dta", replace
	

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
gen double ind_id = hh1*10000 + hh2*100 + hl1
format ind_id %20.0g
label var ind_id "Individual ID"

duplicates report ind_id 


sort ind_id

	
********************************************************************************
*** Step 1.7 DATA MERGING 
******************************************************************************** 
 
 
*** Merging BR Recode 
*****************************************
	//No BH file for Thailand MICS 2019
	
 
*** Merging WM Recode 
*****************************************
merge 1:1 ind_id using "$path_out/THA19_WM.dta"
count if hl8>0
	/*26,002 women 15-49 years were eligible for interview. This matches
	the survey report (page ix) where it is reported that 26,002 women were 
	eligible for interview. */
drop _merge	


*** Merging HH Recode 
*****************************************
merge m:1 hh_id using "$path_out/THA19_HH.dta"
tab hh46 if _m==2 
drop  if _merge==2
	//Drop households that were not interviewed 
drop _merge


*** Merging MN Recode 
*****************************************
merge 1:1 ind_id using "$path_out/THA19_MN.dta"
drop _merge


*** Merging CH Recode 
*****************************************
merge 1:1 ind_id using "$path_out/THA19_CH.dta"
drop _merge


sort ind_id


********************************************************************************
*** Step 1.8 CONTROL VARIABLES
********************************************************************************
/* Households are identified as having 'no eligible' members if there are no 
applicable population, that is, children 0-5 years, adult women or men. These 
households will not have information on relevant indicators of health. As such, 
these households are considered as non-deprived in those relevant indicators. */


*** No eligible women 15-49 years 
*** for child mortality indicator
*****************************************
count if women_WM==1
count if hl8>0 & hl8!=.
	//Eligibility based on WM datafile (women_WM) and HL datafile (hl8) matches
gen	fem_eligible = (women_WM==1)
bys	hh_id: egen hh_n_fem_eligible = sum(fem_eligible) 	
	//Number of eligible women for interview in the hh
gen	no_fem_eligible = (hh_n_fem_eligible==0) 									
	//Takes value 1 if the household had no eligible females for an interview
lab var no_fem_eligible "Household has no eligible women"
drop fem_eligible hh_n_fem_eligible 
tab no_fem_eligible, miss


*** No eligible men 15-49 years
*** for child mortality indicator (if relevant)
*****************************************
count if men_MN==1
count if hl9>0 & hl9!=.
	//Eligibility based on MN datafile (men_MN) and HL datafile (hl9) matches
gen	male_eligible = (men_MN==1)
bysort	hh_id: egen hh_n_male_eligible = sum(male_eligible)  
	//Number of eligible men for interview in the hh
gen	no_male_eligible = (hh_n_male_eligible==0) 	
	//Takes value 1 if the household had no eligible men for an interview
lab var no_male_eligible "Household has no eligible man for interview"
drop male_eligible hh_n_male_eligible
tab no_male_eligible, miss

	
*** No eligible children under 5
*** for child nutrition indicator
*****************************************
count if child_CH==1
count if hl10>0 & hl10!=.
	//Eligibility based on CH datafile (child_CH) and HL datafile (hl10) matches
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
clonevar area = hh6  
replace area=0 if area==2  
label define lab_area 1 "urban" 0 "rural"
label values area lab_area
label var area "Area: urban-rural"


//Relationship to the head of household
desc hl3
clonevar relationship = hl3 
codebook relationship, tab (20)
recode relationship (1=1)(2=2)(3 13=3)(4/12=4)(96=5)(14=6)(97=.)(98=.)
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
compare hhsize hh48
	/*hh48 comes with the datafile. We find that the hhsize variable that 
	we generated matches the original variable from the data file.*/ 
drop member


//Religion of the household head
clonevar religion_hh = hc1a
label var religion_hh "Religion of household head"
codebook religion_hh, tab (99)

//Ethnicity of the household head
gen ethnic_hh = .
label var ethnic_hh "Ethnicity of household head"
codebook ethnic_hh, tab (99)


//Subnational region
	/* The sample for the Thailand MICS 2019 was designed to provide 
	estimates for a large number of indicators on the situation  of children 
	and women at the national level, for urban and rural areas, and for the 
	five regions (Bangkok, Central, North, Northeast and South) of the country
	(see p. 251 of report).  */   
	
codebook hh7, tab (99) 
clonevar region = hh7
lab var region "Region for subnational decomposition"
codebook region, tab (99)


********************************************************************************
***  Step 2 Data preparation  ***
***  Standardization of the 10 Global MPI indicators 
***  Identification of non-deprived & deprived individuals  
********************************************************************************

********************************************************************************
*** Step 2.1 Years of Schooling ***
********************************************************************************

/*In Thailand, children enter primary school at age 6, lower secondary at 
age 12 and upper secondary school at age 15. There are 6 grades in primary 
school and 3 + 3 grades in secondary school. In primary school, grades are 
referred to as Prathomsuksa 1 to Prathomsuksa 6. For lower secondary school, 
grades are referred to as Mattayomsuksa 1 to Mattayomsuksa 3 and in upper 
secondary to Mattayomsuksa 4 to Mattayomsuksa 6.(p.160 of country report). */


codebook ed5a, tab (99)
tab age ed10a if ed5a==0, miss
	//The category ECE indicate early childhood education, that is, pre-primary
clonevar edulevel = ed5a 
	//Highest educational level attended
replace edulevel = . if ed5a==. | ed5a==98 | ed5a==99  
	//All missing values or out of range are replaced as "."
replace edulevel = 0 if ed4==2 
	//Those who never attended school are replaced as '0'
replace edulevel = 0 if ed5b==95 
	//Those who attended non-formal school are replaced as '0'		
label var edulevel "Highest level of education attended"


codebook ed5b, tab (99)
tab ed5b ed5a, miss
clonevar eduhighyear = ed5b 
	//Highest grade attended at that level
replace eduhighyear = .  if ed5b==. | ed5b==98 | ed5b==99 
	//All missing values or out of range are replaced as "."
replace eduhighyear = 0  if ed5b==95 
	//Those who attended non-formal school are replaced as '0'	
replace eduhighyear = 0  if ed4==2 
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

	
*** Now we create the years of schooling
tab eduhighyear edulevel, miss
gen	eduyears = eduhighyear
replace eduyears = eduhighyear + 6 if edulevel==2 
replace eduyears = eduhighyear + 6 if edulevel==3 & eduhighyear!=0
replace eduyears = eduhighyear + 9 if edulevel==3 & eduhighyear==0
	/*There are 6 grades in primary school; followed by 3 grades in lower
	secondary school and 3 grades in upper secondary school. As such, we add 
	6 years to each of the grades completed at the secondary level. However,
	for individuals who reported grade 0 at the upper secondary level, we 
	assume they completed 6 years of primary and 3 years of lower secondary.*/		
replace eduyears = eduhighyear + 12 if edulevel==4 | edulevel==5 | edulevel==6
	/*Individuals would have completed 12 years of schooling before reaching 
	post secondary education, or university education or vocational training.
	As such we add 12 years to each of the grades completed at the higher 
	education and vocation level.*/
replace eduyears = eduhighyear + 16 if edulevel==7 | edulevel==8 
	/*Individuals would have completed 16 years of schooling before reaching 
	postgraduate degree.*/	
replace eduyears = 6 if edulevel==2 & eduhighyear==.
	/*We assume that an individual who has lower secondary education but no 
	information on grade, has completed primary schooling. */ 
replace eduyears = 9 if edulevel==3 & eduhighyear==.
	/*We assume that an individual who has upper secondary education but no 
	information on grade, has completed lower secondary schooling. */ 	
replace eduyears = 12 if edulevel==4 & eduhighyear==.
replace eduyears = 12 if edulevel==6 & eduhighyear==.
	/*We assume that an individual who has vocational/diploma/higher edu
	but no information on grade, has completed secondary school. */ 	
replace eduyears = 16 if edulevel==8 & eduhighyear==.
	/*We assume that an individual who has postgraduate degree but no 
	information on the total year of the postgraduate studies, has completed 
	16 years of education. */ 


*** Checking for further inconsistencies 
replace eduyears = eduyears - 1 if ed6==2 & eduyears>=1 & eduyears<. 
	/*Through ed6 variable, individuals confirm whether they have completed the 
	highest grade they have attended. For individuals who responded that they 
	did not complete the highest grade attended, we re-assign them to the next  
	lower grade that they would have completed. */
replace eduyears = . if age<=eduyears & age>0 
	/*There are cases in which the years of schooling are greater than the 
	age of the individual. This is clearly a mistake in the data.*/
replace eduyears = 0 if age< 10
replace eduyears = 0 if (age==10 | age==11) & eduyears < 6 
	/*The variable "eduyears" was replaced with a '0' for ineligible household 
	members, i.e.: those who have not completed 6 years of schooling following 
	their starting school age */
replace eduyears = . if eduhighyear!=. & edulevel==. & ed4==1
	/*Replaced as missing value when level of education is missing for those 
	who have attended school */
lab var eduyears "Total number of years of education accomplished"
tab eduyears, miss
tab eduyears edulevel, miss	


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
	//The value for 0 (missing) is 0.10% 
label var no_missing_edu "No missing edu for at least 2/3 of the eligible HH members"
drop temp temp2 hhs


*** Standard MPI ***
/*The entire household is considered deprived if no eligible 
household member has completed SIX years of schooling. */
******************************************************************* 
gen	 years_edu6 = (eduyears>=6)
	/* The years of schooling indicator takes a value of "1" if at least someone 
	in the hh has reported 6 years of education or more */
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
	
codebook ed4 ed9, tab (99)

gen	attendance = .
replace attendance = 1 if ed9==1 
	//Replace attendance with '1' if currently attending school	
replace attendance = 0 if ed9==2 
	//Replace attendance with '0' if currently not attending school	
replace attendance = 0 if ed4==2 
	//Replace attendance with '0' if never ever attended school	
tab age ed9, miss	
	//Check individuals who are not of school age	
replace attendance = 0 if age<5 | age>24 
	//Replace attendance with '0' for individuals who are not of school age	
label define lab_attend 1 "currently attending" 0 "not currently attending"
label values attendance lab_attend
label var attendance "Attended school during current school year"	
tab attendance, miss


*** Standard MPI ***
/*The entire household is considered deprived if any school-aged 
child is not attending school up to class 8. */ 
******************************************************************* 

gen	child_schoolage = (schage>=6 & schage<=14)
	/*In Thailand, the official school entrance age to primary school is 
	6 years. So, age range is 6-14 (=6+8). 
	Source 1: See page 160 of report for primary school entry age. 
	Source 2: "http://data.uis.unesco.org/?ReportId=163"
	Go to Education>Education>System>Official entrance age to primary education. 
	Look at the starting age and add 8. 
	*/

	
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
	/*If the household has been intially identified as non-deprived, but has 
	missing school attendance for at least 2/3 of the school aged children, then 
	we replace this household with a value of '.' because there is insufficient 
	information to conclusively conclude that the household is not deprived */
lab var hh_child_atten "Household has all school age children up to class 8 in school"
tab hh_child_atten [aw = weight], miss

/*Note: The indicator takes value 1 if ALL children in school age are attending 
school and 0 if there is at least one child not attending. Households with no 
children receive a value of 1 as non-deprived. The indicator has a missing value 
only when there are all missing values on children attendance in households that 
have children in school age. */

	
*** Destitution MPI ***
/*The entire household is considered deprived if any school-aged 
child is not attending school up to class 6. */ 
******************************************************************* 
gen	child_schoolage_6 = (schage>=6 & schage<=12) 
	/*In Thailand, the official school entrance age is 6 years.  
	  So, age range for destitution measure is 6-12 (=6+6) */

	
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
tab hh_child_atten_u [aw = weight], miss


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
	//Takes value 1 if no child in the hh is stunted
replace hh_no_stunting = . if temp==.
replace hh_no_stunting = 1 if no_child_eligible==1 
	//Households with no eligible children will receive a value of 1
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
	//Takes value 1 if no child in the hh is wasted
replace hh_no_wasting = . if temp==.
replace hh_no_wasting = 1 if no_child_eligible==1 
	//Households with no eligible children will receive a value of 1
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
	//Takes value 1 if child in the hh is stunted or underweight 
replace uw_st = 0 if stunting==0 & underweight==0
	//Takes value 0 if child in the hh is not stunted and not underweight 
replace uw_st = . if stunting==. & underweight==.

bysort hh_id: egen temp = max(uw_st)
gen hh_no_uw_st = (temp==0) 
replace hh_no_uw_st = . if temp==.
drop temp
replace hh_no_uw_st = 1 if no_child_eligible==1
	//Households with no eligible children will receive a value of 1 
lab var hh_no_uw_st "HH has no child underweight or stunted"


*** Destitution MPI  ***
gen uw_st_u = 1 if stunting_u==1 | underweight_u==1
replace uw_st_u = 0 if stunting_u==0 & underweight_u==0
replace uw_st_u = . if stunting_u==. & underweight_u==.

bysort hh_id: egen temp = max(uw_st_u)
gen hh_no_uw_st_u = (temp==0) 
replace hh_no_uw_st_u = . if temp==.
drop temp
replace hh_no_uw_st_u = 1 if no_child_eligible==1
lab var hh_no_uw_st_u "DST: HH has no child underweight or stunted"


*** Quality check ***
/* Compare the proportion of children under 5 who is stunted between the survey 
report and this dataset. */ 
*****************************************************************************

tab stunting [aw = weight] if child_CH==1
	/* Thailand MICS 2019: The country survey report indicate that 13.3% of 
	children are stunted (p.144), while it is 13.29% in this data. 
	The figure based on this dataset corresponds to the figure reported in the 
	survey report.*/


********************************************************************************
*** Step 2.3b Household Nutrition Indicator ***
********************************************************************************

*** Standard MPI ***
/* The indicator takes value 1 if the household has no child under 5 who 
has either height-for-age or weight-for-age that is under two standard 
deviation below the median. It also takes value 1 for the households that 
have no eligible children. The indicator takes a value of missing only if 
all eligible children have missing information in their respective 
nutrition variable. */
************************************************************************
gen	hh_nutrition_uw_st = 1
replace hh_nutrition_uw_st = 0 if hh_no_uw_st==0
replace hh_nutrition_uw_st = . if hh_no_uw_st==.
replace hh_nutrition_uw_st = 1 if no_child_eligible==1   
 	/*We replace households that do not have the applicable population, that is, 
	children 0-5, as non-deprived in nutrition*/		
lab var hh_nutrition_uw_st "HH has no individuals malnourished"
tab hh_nutrition_uw_st [aw = weight], miss


*** Destitution MPI ***
/* The indicator takes value 1 if the household has no child under 5 who 
has either height-for-age or weight-for-age that is under three standard 
deviation below the median. It also takes value 1 for the households that 
have no eligible children. The indicator takes a value of missing only if 
all eligible children have missing information in their respective 
nutrition variable. */
************************************************************************
gen	hh_nutrition_uw_st_u = 1
replace hh_nutrition_uw_st_u = 0 if hh_no_uw_st_u==0
replace hh_nutrition_uw_st_u = . if hh_no_uw_st_u==.
replace hh_nutrition_uw_st_u = 1 if no_child_eligible==1   
 	/*We replace households that do not have the applicable population, that is, 
	children 0-5, as non-deprived in nutrition*/		
lab var hh_nutrition_uw_st_u "DST: HH has no individuals malnourished"
tab hh_nutrition_uw_st_u [aw = weight], miss


********************************************************************************
*** Step 2.4 Child Mortality ***
********************************************************************************

codebook cm9 cm10 mcm9 mcm10
	/*cm9 or mcm9: number of sons who have died 
	  cm10 or mcm10: number of daughters who have died */
	  
	  
tab cm1 cm8, miss
	/*Identify the number of women who never gave birth 
	but has birth history data: 10 women.
	We make use of the birth history information from
	these women.*/
	
	
egen temp_f = rowtotal(cm9 cm10), missing
	//Total child mortality reported by eligible women
replace temp_f = 0 if (cm1==1 & cm8==2) | (cm1==2 & cm8==2) 
	/*Assign a value of "0" for:
	- all eligible women who have ever gave birth but reported no child death 
	- all eligible women who never ever gave birth and reported no child death*/
bysort	hh_id: egen child_mortality_f = sum(temp_f), missing
lab var child_mortality_f "Occurrence of child mortality reported by women"
tab child_mortality_f, miss
drop temp_f
	

tab mcm1 mcm8, miss
tab mcm9 if mcm1==2 & mcm8==1,miss
tab mcm10 if mcm1==2 & mcm8==1,miss
	/*Identify the number of men who never fathered a child 
	but has reported child death: 5 men.
	We make use of the child mortality information reported by these men.*/

egen temp_m = rowtotal(mcm9 mcm10), missing
	//Total child mortality reported by eligible men	
replace temp_m = 0 if (mcm1==1 & mcm8==2) | (mcm1==2 & mcm8==2) 
	/*Assign a value of "0" for:
	- all eligible men who ever fathered children but reported no child death. 
	- all eligible men who never fathered children and reported no child death.*/
bysort	hh_id: egen child_mortality_m = sum(temp_m), missing	
lab var child_mortality_m "Occurrence of child mortality reported by men"
tab child_mortality_m, miss
drop temp_m


egen child_mortality = rowmax(child_mortality_f child_mortality_m)
replace child_mortality = 0 if child_mortality==. & no_fem_eligible==1 & no_male_eligible==1
lab var child_mortality "Total child mortality within HH"
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
replace hh_mortality = 1 if no_fem_eligible==1 & no_male_eligible==1
	/*Household is replaced with a value of "1" if there is 
	no eligible women or men */
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
/*Members of the household are considered deprived 
if the household has no electricity */
****************************************
clonevar electricity = hc8 
codebook electricity, tab (9)
replace electricity = 1 if electricity==1 | electricity==2
replace electricity = 0 if electricity==3
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


*** Quality check ***
/* We compare the proportion of households with 
electricity obtained from our work and as reported in 
the country survey report. */
*********************************************************
tab electricity [aw = weight],miss
	/*In the report, Table SR.2.1 (p.27) indicate that 99.9% of household 
	members have access to electricity. The results obtained from our work is 
	99.9% which matches the report. */

	
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

In cases of mismatch between the country report and the internationally 
agreed guideline, we followed the report.
*/
desc ws11 ws15  
clonevar toilet = ws11  
clonevar shared_toilet = ws15 
codebook shared_toilet, tab(99)  
recode shared_toilet (2=0)
replace shared_toilet=. if shared_toilet==9
tab ws11 shared_toilet, miss nol
	
		
*** Standard MPI ***
/*Members of the household are considered deprived if the household's 
sanitation facility is not improved (according to the SDG guideline) 
or it is improved but shared with other households*/
********************************************************************
codebook toilet, tab(99) 

gen	toilet_mdg = (toilet<=22 & shared_toilet!=1) 
	/*Household is assigned a value of '1' if it uses improved sanitation and 
	does not share toilet with other households  */
	
replace toilet_mdg = 0 if toilet == 14
	/*Household is assigned a value of '0' if it uses non-improved sanitation: 
	"flush to elsewhere" */	
	
replace toilet_mdg = . if toilet==99 | toilet==.
	//Household is assigned a value of '.' if it has missing information 

tab shared_toilet if toilet==99 | toilet==.,miss		
replace toilet_mdg = 0 if shared_toilet==1
	/*It may be the case that there are individuals who did not respond on the 
	type of toilet, but they indicated that they share their toilet facilities. 
	In such case, we replace these individuals as deprived following the 
	information on shared toilet.*/		

lab var toilet_mdg "Household has improved sanitation"
tab toilet toilet_mdg, miss
tab toilet_mdg, miss	
	
	
*** Destitution MPI ***
/*Members of the household are considered deprived if household practises 
open defecation or uses other unidentifiable sanitation practises */
********************************************************************
gen	toilet_u = .

replace toilet_u = 0 if toilet==95 | toilet==96 
	/*Household is assigned a value of '0' if it practises open defecation or 
	others */

replace toilet_u = 1 if toilet!=95 & toilet!=96 & toilet!=. & toilet!=99
	/*Household is assigned a value of '1' if it does not practise open 
	defecation or others  */

lab var toilet_u "Household does not practise open defecation or others"
tab toilet toilet_u, miss


*** Quality check ***
/* We compare the proportion of household members with 
improved sanitation obtained from our work and as 
reported in the country survey report. */
*********************************************************
tab toilet_mdg [aw = weight],miss
	/*In the report, Table WS.3.2 (p.224) indicate that 97.1% of household 
	members have improved sanitation facilities that are not shared. The 
	results obtained from our work is 97.07% which matches the report. */


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

In cases of mismatch between the country report and the internationally 
agreed guideline, we followed the report.
*/
desc ws1 ws4 ws2
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
gen	water_mdg = 1 if water<=31 | water==51 | water==61 | ///
					 water==91 | water==93 | water==94 			 
	/*Non deprived if water is piped water into dwelling, into yard/plot/to 
	neighbour, public tap/stand pipe tube well/bore hole, protected well, 
	rain water collection, tanker truck, bottled water, packaged water 
	glass/cup, coin operated water dispenser.*/
	
replace water_mdg = 0 if water==32 | water==81
	/*Deprived if it is unprotected well, surface water*/
	
replace water_mdg = . if water==99 | water==.						 
lab var water_mdg "Household has safe drinking water on premises"
tab water water_mdg, miss	
tab water_mdg, miss

		
*** Quality check ***
/* We compare the proportion of household members with 
improved access to safe drinking water as obtained from 
our work and as reported in the country survey report. */
*********************************************************
tab water_mdg [aw = weight],miss
	/*In the report, Table WS.1.1 (p.213), 99.5% of household members 
	have improved or safe drinking facilities. The results obtained from our 
	work is 99.52%, which matches the report. */	 	
	
	
*** Time to water ***	
********************************************************* 
codebook timetowater, tab(999)
	
replace water_mdg = 0 if water_mdg==1 & timetowater >= 30 & timetowater!=. & ///
						 timetowater!=998 & timetowater!=999
	/*Deprived if water is at more than 30 minutes' walk (roundtrip). Missing 
	observations excluded. */
	  	
tab timetowater if water==99 | water==.,miss	
replace water_mdg = 0 if (water==99 | water==.) & water_mdg==. & ///
						  timetowater >= 30 & timetowater!=. & ///
						  timetowater!=998 & timetowater!=999 
	/*It may be the case that there are individuals who did not respond on their 
	source of drinking water, but they indicated the water source is 30 minutes 
	or more from home, roundtrip. In such case, we replace these individuals as
	deprived following the information on distance to water.*/	


*** Destitution MPI ***
/* Members of the household is identified as destitute if household 
does not have access to safe drinking water, or safe water is more 
than 45 minute walk from home, round trip.*/
********************************************************************
gen	water_u = .
					   
replace	water_u = 1 if water<=31 | water==51 | water==61 | ///
					   water==91 | water==93 | water==94 						   
					   
replace water_u = 0 if water==32 | water==81
					   
replace water_u = 0 if water_u==1 & timetowater> 45 & timetowater!=. ///
					   & timetowater!=998 & timetowater!=999 	
					   
replace water_u = . if water==99 | water==.	

replace water_u = 0 if (water==99 | water==.) & water_u==. & ///
						timetowater > 45 & timetowater!=. & ///
						timetowater!=998 & timetowater!=999 
					
lab var water_u "Household has safe drinking water (considering distance)"
tab water water_u, miss
tab water_u, miss


********************************************************************************
*** Step 2.8 Housing ***
********************************************************************************

/* Members of the household are considered deprived if the household 
has a dirt, sand, dung or other floor */
lookfor floor sol 
clonevar floor = hc4
codebook floor, tab(99)
gen	floor_imp = 1
replace floor_imp = 0 if floor<=11 | floor==96 	
replace floor_imp = . if floor==. | floor==99
lab var floor_imp "Household has floor that it is not earth/sand/dung"
tab floor floor_imp, miss	


/* Members of the household are considered deprived if the household has walls 
made of natural or rudimentary materials. We followed the report's definitions
of natural or rudimentary materials. */
lookfor wall mur
clonevar wall = hc6
codebook wall, tab(99)
gen	wall_imp = 1 
replace wall_imp = 0 if wall<=26 | wall==96 		
replace wall_imp = . if wall==. | wall==99	
lab var wall_imp "Household has wall that it is not of low quality materials"
tab wall wall_imp, miss	

		
/* Members of the household are considered deprived if the household has roof 
made of natural or rudimentary materials. We followed the report's definitions
of natural and rudimentary materials. */
lookfor roof toit
clonevar roof = hc5
codebook roof, tab(99)	
gen	roof_imp = 1 
replace roof_imp = 0 if roof<=23  | roof==96	
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


*** Quality check ***
/* We compare the proportion of households with 
improved floor, walls and roof from our work and as 
reported in the country survey report. */
*********************************************************
bysort hh_id: gen id = _n
tab floor_imp [aw = weight] if id==1,m
	/*In the report, Table SR.2.1 (p.27) indicate that 0.4% of 
	households have natural floor. The results obtained from our work is 0.4%,
	which matches the survey report.  */	

tab wall_imp [aw = weight] if id==1,m
	/*In the report, Table SR.2.1 (p.27) indicate that 98% of 
	households have improved wall (built using finished material). 
	The results obtained from our work is 98% which matches the report. */	
	
tab roof_imp [aw = weight] if id==1,m
	/*In the report, Table SR.2.1 (p.27) indicate that 99.5% of 
	households have improved roof (built using finished material). 
	The results obtained from our work is 99.46% which matches the report. */	
	
		
********************************************************************************
*** Step 2.9 Cooking Fuel ***
********************************************************************************

/*
Solid fuel are solid materials burned as fuels, which includes coal as well as 
solid biomass fuels (wood, animal dung, crop wastes and charcoal). 

Source: 
https://apps.who.int/iris/bitstream/handle/10665/141496/9789241548885_eng.pdf
*/

lookfor cooking combustible cookstove
clonevar cookingfuel = eu4 
	//eu4 = type of fuel or energy source used for the cookstove

	
*** Standard MPI ***
/* Members of the household are considered deprived if the 
household uses solid fuels and solid biomass fuels for cooking. */
*****************************************************************
codebook eu1 cookingfuel, tab(99)
tab eu1 cookingfuel, miss
	/*We analysed the combination between cookingfuel (eu4) and 
	cookstove (eu1). Missing value was applied when individuals lack 
	information for both edu4 and edu1.
	
	If individuals use a cookstove that is designed for solid fuel (eu1) but 
	they use clean fuel for cooking (eu4), these individuals are identified
	as non-deprived (1). 
	
	If individuals use a cookstove that is designed for clean fuel (eu1) but 
	they use solid fuel for cooking (eu4), these individuals are identified
	as deprived (0). */

gen	cooking_mdg = 1
replace cooking_mdg = 0 if cookingfuel>=4 & cookingfuel<=11
	/* Deprived if: coal/lignite, charcoal, wood, straw/shrubs/grass, 
					agricultural crop, animal dung, woodchips, sawdust */	
						
replace cooking_mdg = 0 if eu1==10 & cookingfuel==96
	/*Thailand MICS 2019: 10 individuals reported using charcoal cookstove, 
	with other type of fuel. Since the stove is designed for solid fuel, we 
	assume these 10 individuals used solid fuel.*/
	
replace cooking_mdg = . if cookingfuel==. & eu1==.
	//Missing values replaced.
	
lab var cooking_mdg "Household cooks with clean fuels"	
tab cookingfuel cooking_mdg, miss
tab eu1 cooking_mdg, miss
tab cooking_mdg, miss


*** Destitution MPI ***
*** (same as standard MPI) ***
****************************************	
gen	cooking_u = cooking_mdg
lab var cooking_u "Household cooks with clean fuels"


*** Quality check ***
/* We compare the proportion of household members using 
clean fuels & technologies for cooking obtained from 
our work and as reported in the country survey report. */
*********************************************************
tab cooking_mdg [aw = weight],miss
	/*In the report, Table TC.2.1 (page 123) indicate that 83.9% of household 
	members use clean fuels & technologies for cooking. The results obtained 
	from our work is 84.35%, which closely matches the report.*/	
	

********************************************************************************
*** Step 2.10 Assets ownership ***
********************************************************************************

*** Television/LCD TV/plasma TV/color TV/black & white tv
lookfor tv television plasma lcd télé
codebook hc9a hc9b
tab hc9a hc9b, miss
clonevar television = hc9a
replace television=1 if television!=1 & hc9b==1 
lab var television "Household has television"
tab hc9a hc9b if television==1,miss
tab electricity television, miss
replace television=0 if electricity==0 & television==.	
	/*We make an assumption that there is no television in these households 
	given that there is no electricity. */

		
***	Radio/walkman/stereo/kindle
lookfor radio walkman stereo stéréo
codebook hc7b
clonevar radio = hc7b 
lab var radio "Household has radio"	



***	Handphone/telephone/iphone/mobilephone/ipod
lookfor telephone téléphone mobilephone ipod
codebook hc7a hc12
clonevar telephone = hc7a
replace telephone=1 if telephone!=1 & hc12==1	
	//hc12=mobilephone. Combine information on telephone and mobilephone.	
tab hc7a hc12 if telephone==1,miss
lab var telephone "Household has telephone (landline/mobilephone)"	

	
***	Refrigerator/icebox/fridge
lookfor refrigerator réfrigérateur
codebook hc9f
clonevar refrigerator = hc9f
lab var refrigerator "Household has refrigerator"
tab refrigerator, miss 
tab electricity refrigerator, miss
replace refrigerator=0 if electricity==0 & refrigerator==.	
	/*We make an assumption that there is no refrigerator in these households 
	given that there is no electricity.*/


***	Car/van/lorry/truck
lookfor car voiture truck van
codebook hc10e
clonevar car = hc10e  
lab var car "Household has car"		

	
***	Bicycle/cycle rickshaw
lookfor bicycle bicyclette
codebook hc10b
clonevar bicycle = hc10b 
lab var bicycle "Household has bicycle"	
	
	
***	Motorbike/motorized bike/autorickshaw
lookfor motorbike moto
codebook hc10c hc10i	
clonevar motorbike = hc10c
replace motorbike=1 if motorbike!=1 & hc10i==1	
lab var motorbike "Household has motorbike"

	
***	Computer/laptop/tablet
lookfor computer ordinateur laptop ipad tablet
codebook hc11
clonevar computer = hc11
lab var computer "Household has computer"


***	Animal cart
lookfor brouette charrette cart
gen animal_cart = .
lab var animal_cart "Household has animal cart"	
 
 
foreach var in television radio telephone refrigerator car ///
			   bicycle motorbike computer animal_cart {
replace `var' = 0 if `var'==2 
label define lab_`var' 0"No" 1"Yes"
label values `var' lab_`var'			   
replace `var' = . if `var'==9 | `var'==99 | `var'==8 | `var'==98 
}
	//Labels defined and missing values replaced	
	

*** Quality check ***
/* We compare the proportion of households owning  
each assets obtained from our work and as reported 
in the country survey report. */
*********************************************************
	
tab radio [aw = weight] if id==1,miss
	/*Table SR.8.1 (p.43) indicate that 27.7% of households own radio. 
	The results obtained from our work is 27.69% which matches the report.*/	

tab television [aw = weight] if id==1,miss
	/*Table SR.8.1 (p.43) indicate that 94% of households own 
	television. The results obtained from our work is 93.98% which matches the 
	report.*/	
	
tab telephone [aw = weight] if id==1,miss
	/*Table SR.8.1 (p.43) indicate that 95.5% of households own either fixed 
	line or mobile phone. The results obtained from our work is 95.46% which 
	matches the report. */

tab computer [aw = weight] if id==1,miss
	/*Table SR.8.1 (p.43) indicate that 25.7% of households own computer. 
	The results obtained from our work is 25.67% which matches the report.*/
	
tab refrigerator [aw = weight] if id==1,miss
	/*Table SR.2.2 (p.28) indicate that 92.2% of households own 
	refrigerator. The results obtained from our work is 92.2% which matches 
	the report.*/

tab bicycle [aw = weight] if id==1,miss
	/*Table SR.2.2 (p.28) indicate that 55% of households own bicycle. 
	The results obtained from our work is 55% which matches the report.*/

tab animal_cart [aw = weight] if id==1,miss
	/*NA*/

tab motorbike [aw = weight]if id==1,miss
	/*Table SR.2.2 (p.28) indicate that 80.1% of households own bicycle. 
	The results obtained from our work is 80.39% which closely matches the 
	report because our work also includes large motorcycle (big bike).*/

tab car [aw = weight] if id==1,miss
	/*Table SR.2.2 (p.28) indicate that 48.3% of households own car. 
	The results obtained from our work is 48.25% which matches the report.*/



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
*gen psu = hh1
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
n_small_assets2 hh_assets2 hh_assets2_u 

	 
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
n_small_assets2 hh_assets2 hh_assets2_u 


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
recode hh_mortality		    (0=1)(1=0) , gen(d_cm_01)
recode hh_nutrition_uw_st 	(0=1)(1=0) , gen(d_nutr_01)
recode hh_child_atten 		(0=1)(1=0) , gen(d_satt_01)
recode hh_years_edu6 		(0=1)(1=0) , gen(d_educ_01)
recode electricity 			(0=1)(1=0) , gen(d_elct_01)
recode water_mdg 			(0=1)(1=0) , gen(d_wtr_01)
recode toilet_mdg 			(0=1)(1=0) , gen(d_sani_01)
recode housing_1 			(0=1)(1=0) , gen(d_hsg_01)
recode cooking_mdg 			(0=1)(1=0) , gen(d_ckfl_01)
recode hh_assets2 			(0=1)(1=0) , gen(d_asst_01)	
	

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
 	
 
	/*In this survey, the harmonised 'region_01' variable is the 
	same as the standardised 'region' variable.*/	
clonevar region_01 = region 

 

char _dta[cty] "Thailand"
char _dta[ccty] "THA"
char _dta[year] "2019" 	
char _dta[survey] "MICS"
char _dta[ccnum] "764"
char _dta[type] "micro"



sort ind_id
compress
la da "Micro data for `_dta[ccty]' (`_dta[ccnum]') from `c(current_date)' (`c(current_time)')."
save "$path_out/tha_mics19.dta", replace 


gen educ_elig = 1 
replace educ_elig = 0 if age < 10 
replace educ_elig = 0 if (age==10 | age==11) & eduyears < 6 
label define lab_educ_elig 0"ineligible" 1"eligible"  
label values educ_elig lab_educ_elig
lab var educ_elig "Individual is eligible for educ indicator"
tab eduyears educ_elig,m
