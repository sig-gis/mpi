

clear all 
set more off
set maxvar 10000


*** Working Folder Path ***
global path_in "../rdta/Benin DHS 2017-18"	  
global path_out "cdta"
global path_ado "ado"


********************************************************************************
*** BENIN DHS 2017-18 ***
********************************************************************************


********************************************************************************
*** Step 1: Data preparation 
*** Selecting variables from KR, BR, IR, & MR recode & merging with PR recode 
********************************************************************************
		

********************************************************************************
*** Step 1.1 PR - INDIVIDUAL RECODE
*** (Children under 5 years) 
********************************************************************************
use "$path_in/BJPR71FL.DTA", clear 


*** Generate individual unique key variable required for data merging using:
	*** hv001=cluster number; 
	*** hv002=household number; 
	*** hvidx=respondent's line number.
gen double ind_id = hv001*1000000 + hv002*100 + hvidx 
format ind_id %20.0g
label var ind_id "Individual ID"
codebook ind_id


duplicates report ind_id


tab hv120, miss
	//13,708 children under 5 are eligible for anthropometric measurement	
count if hc1!=.
	//All 13,708 children under 5 have information on age in months
tab hv105 if hc1!=.
	/*A cross check with the age in years reveal that all are within the 5 year 
	age group */
tab hc13 if hc1!=., miss
	/*Of the 13,708 children, 13,436 have been measured while 272 have 
	missing information */
tab hc13 if hc1!=. & hc3<=9990, miss
tab hc13 if hc1!=. & hc2<=9990, miss
	/*For example, height and weight data is available for all 5,866 children 
	who have been successfully measured */


	/*Following the checks carried out above, we keep only eligible children in
	this section since the interest is to generate measures for children under 
	5*/
keep if hv120==1
count	
	//13,708 children under 5		
	
	
*** Check the variables to calculate the z-scores:

*** Variable: SEX ***
desc hc27 hv104
	/*hc27=sex of the child from biomarker questionnaire;
	hv104=sex from household roaster */
compare hc27 hv104
	//hc27 should match with hv104
tab hc27, miss 
	//"1" for male ;"2" for female 
tab hc27, nol 
clonevar gender = hc27
tab gender


*** Variable: AGE ***
tab hc1, miss  
codebook hc1 
clonevar age_months = hc1  
desc age_months
sum age_months

gen mdate = mdy(hc18, hc17, hc19)
gen bdate = mdy(hc30, hc16, hc31) if hc16 <= 31
	//Calculate birth date in days from date of interview
replace bdate = mdy(hc30, 15, hc31) if hc16 > 31 
	//If date of birth of child has been expressed as more than 31, we use 15
gen age = (mdate-bdate)/30.4375 
	//Calculate age in months with days expressed as decimals

gen  str6 ageunit = "months" 
lab var ageunit "Months"

	
*** Variable: BODY WEIGHT (KILOGRAMS) ***
codebook hc2, tab (9999)
gen	weight = hc2/10 
	//We divide it by 10 in order to express it in kilograms 
tab hc2 if hc2>9990, miss nol   
	//Missing values are 9994 to 9996
replace weight = . if hc2>=9990 
	//All missing values or out of range are replaced as "."
tab	hc13 hc2 if hc2>=9990 | hc2==., miss 
	//hw13: result of the measurement
sum weight


*** Variable: HEIGHT (CENTIMETERS)
codebook hc3, tab (9999)
gen	height = hc3/10 
	//We divide it by 10 in order to express it in centimeters
tab hc3 if hc3>9990, miss nol   
	//Missing values are 9994 to 9996
replace height = . if hc3>=9990 
	//All missing values or out of range are replaced as "."
tab	hc13 hc3   if hc3>=9990 | hc3==., miss
sum height


*** Variable: MEASURED STANDING/LYING DOWN ***	
codebook hc15
gen measure = "l" if hc15==1 
	//Child measured lying down
replace measure = "h" if hc15==2 
	//Child measured standing up
replace measure = " " if hc15==9 | hc15==0 | hc15==. 
	//Replace with " " if unknown
tab measure


*** Variable: OEDEMA ***
lookfor oedema
gen  oedema = "n"  
	//We assume every individual in the sample has no oedema
tab oedema	


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

/* We use 'reflib' to specify the package directory where the .dta files 
containing the WHO Child Growth Standards are stored.*/	
gen str100 reflib = "$path_ado/igrowup_stata"
lab var reflib "Directory of reference tables"

/* We use datalib to specify the working directory where the input STATA 
dataset containing the anthropometric measurement is stored. */
gen str100 datalib = "$path_out" 
lab var datalib "Directory for datafiles"

/* We use datalab to specify the name that will prefix the output files that 
will be produced from using this ado file (datalab_z_r_rc and datalab_prev_rc)*/
gen str30 datalab = "children_nutri_ben" 
lab var datalab "Working file"

	
/*We now run the command to calculate the z-scores with the adofile */
igrowup_restricted reflib datalib datalab gender age ageunit weight height ///
measure oedema sw


/*We now turn to using the dta file that was created and that contains 
the calculated z-scores to create the child nutrition variables following WHO 
standards */
use "$path_out/children_nutri_ben_z_rc.dta", clear 

	
*** Standard MPI indicator ***
	//Takes value 1 if the child is under 2 stdev below the median & 0 otherwise	
gen	underweight = (_zwei < -2.0) 
replace underweight = . if _zwei == . | _fwei==1
lab var underweight  "Child is undernourished (weight-for-age) 2sd - WHO"
tab underweight [aw=hv005], miss


gen stunting = (_zlen < -2.0)
replace stunting = . if _zlen == . | _flen==1
lab var stunting "Child is stunted (length/height-for-age) 2sd - WHO"
tab stunting [aw=hv005], miss


gen wasting = (_zwfl < - 2.0)
replace wasting = . if _zwfl == . | _fwfl == 1
lab var wasting  "Child is wasted (weight-for-length/height) 2sd - WHO"
tab wasting [aw=hv005], miss


*** Destitution MPI indicator  ***
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
	/*Benin DHS 2017-18: 68 children were replaced as missing because
	they have extreme z-scores which are biologically implausible. */
 
count if stunting!=. & hc13==0 & hv102==1
	/*13,170 children under 5 who are usual residents was measured and have 
	height-for-age (stunting) indicator. Table 11.1 (sum 'number of children' by 
	age in months, p.227) indicate that height-for-age indicator covered 12,777 
	children. */  
 
 
gen weight_ch = hv005/1000000
label var weight_ch "sample weight child under 5" 

 
	//Retain relevant variables:
keep  ind_id weight_ch underweight* stunting* wasting* 
order ind_id weight_ch underweight* stunting* wasting*
sort  ind_id
save "$path_out/BEN17-18_PR_child.dta", replace
	
	
	//Erase files from folder:
erase "$path_out/children_nutri_ben_z_rc.xls"
erase "$path_out/children_nutri_ben_prev_rc.xls"
erase "$path_out/children_nutri_ben_z_rc.dta"

	
********************************************************************************
*** Step 1.2  BR - BIRTH RECODE 
*** (All females 15-49 years who ever gave birth)  
********************************************************************************
/*The purpose of step 1.2 is to identify children under 18 who died in 
the last 5 years prior to the survey date.*/

use "$path_in/BJBR71FL.dta", clear

	
*** Generate individual unique key variable required for data merging
*** v001=cluster number;  
*** v002=household number; 
*** v003=respondent's line number
gen double ind_id = v001*1000000 + v002*100 + v003 
format ind_id %20.0g
label var ind_id "Individual ID"


desc b3 b7	
gen date_death = b3 + b7
	//Date of death = date of birth (b3) + age at death (b7)
gen mdead_survey = v008 - date_death
	//Months dead from survey = Date of interview (v008) - date of death
gen ydead_survey = mdead_survey/12
	//Years dead from survey
	
gen age_death = b7	
label var age_death "Age at death in months"
tab age_death, miss
	//Check whether the age is in months		
	
codebook b5, tab (10)	
gen child_died = 1 if b5==0
replace child_died = 0 if b5==1
replace child_died = . if b5==.
label define lab_died 1 "child has died" 0 "child is alive"
label values child_died lab_died
tab b5 child_died, miss
	

	/*NOTE: For each woman, sum the number of children who died and compare to 
	the number of sons/daughters whom they reported have died */
bysort ind_id: egen tot_child_died = sum(child_died) 
egen tot_child_died_2 = rsum(v206 v207)
	//v206: sons who have died; v207: daughters who have died
compare tot_child_died tot_child_died_2
	//Benin DHS 2017-18: these figures are identical.
	
	
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

gen women_BR = 1 
	//Identification variable for observations in BR recode

	
	//Retain relevant variables
keep ind_id women_BR childu18_died_per_wom_5y 
order ind_id women_BR childu18_died_per_wom_5y
sort ind_id
save "$path_out/BEN17-18_BR.dta", replace	

		
********************************************************************************
*** Step 1.3  IR - WOMEN's RECODE  
*** (Eligible female 15-49 years in the household)
********************************************************************************

use "$path_in/BJIR71FL.dta", clear

	
*** Generate individual unique key variable required for data merging
*** Hv001=cluster number;  
*** Hv002=household number; 
*** v003=respondent's line number
gen double ind_id = v001*1000000 + v002*100 + v003 
format ind_id %20.0g
label var ind_id "Individual ID"

duplicates report ind_id

tab v012, miss
codebook v201 v206 v207,tab (999)
	/*Benin DHS 2017-18: Fertility and mortality question was only collected 
	from women 15-49 years.*/
	
gen women_IR=1 
	//Identification variable for observations in IR recode


	//Retain relevant variables:
keep ind_id women_IR v003 v005 v012 v201 v206 v207 
order ind_id women_IR v003 v005 v012 v201 v206 v207 
sort ind_id
save "$path_out/BEN17-18_IR.dta", replace

	
********************************************************************************
*** Step 1.4  PR - INDIVIDUAL RECODE  
*** (Girls 15-19 years in the household)
********************************************************************************

use "$path_in/BJPR71FL.dta", clear

		
*** Generate individual unique key variable required for data merging
gen double ind_id = hv001*1000000 + hv002*100 + hvidx 
format ind_id %20.0g
label var ind_id "Individual ID"
codebook ind_id


*** Identify anthropometric sample for girls
tab ha13 if hv105>=15 & hv105<=19 & hv104==2 & hv044==1, miss 
	/*Total number of girls 15-19 years who live in household selected for 
	domestic violence module and have anthropometric data: 1,772 */
tab ha13 hv117 if hv105>=15 & hv105<=19 & hv104==2 & hv044==1, miss
tab ha13 hv103 if hv105>=15 & hv105<=19 & hv104==2 & hv044==1, miss
	/*23 of the 1,772 women 15-19 years are identified as non-eligible
	for the female interview as they did not sleep the night before in the 
	household. Hence they will not have data on child mortality but they have 
	anthropometric information as they were measured. */


*** Keep relevant sample	
keep if hv105>=15 & hv105<=19 & hv104==2 & hv044==1 
count
	//Total girls 15-19 years: 1,772

	
***Variables required to calculate the z-scores to produce BMI-for-age:

*** Variable: SEX ***
codebook hv104, tab (9)
clonevar gender = hv104
	//2:female 


*** Variable: AGE ***
desc hv807c ha32
gen age_month = hv807c - ha32
lab var age_month "Age in months, individuals 15-19 years (girls)"
tab age_month, miss	
	/*Note: For a couple of observations, we find that the age in months is 
	beyond 228 months. In this secton, while calculating the z-scores, these 
	cases will be excluded. However, in section 2.3, we will take the BMI 
	information of these girls. */

	
*** Variable: AGE UNIT ***
gen str6 ageunit = "months" 
lab var ageunit "Months"

			
*** Variable: BODY WEIGHT (KILOGRAMS) ***
codebook ha2, tab (9999)
count if ha2>9990 
tab ha13 if ha2>9990, miss
gen weight = ha2/10 if ha2<9990
	/*Weight information from girls. We divide it by 10 in order to express 
	it in kilograms. Missing values or out of range are identified as "." */	
sum weight


*** Variable: HEIGHT (CENTIMETERS)	
codebook ha3, tab (9999)
count if ha3>9990 
tab ha13 if ha3>9990, miss
gen height = ha3/10 if ha3<9990
	/*Height information from girls. We divide it by 10 in order to express 
	it in centimeters. Missing values or out of range are identified as "." */
sum height


*** Variable: OEDEMA
	// We assume all individuals in the sample have no oedema
gen oedema = "n"  
tab oedema	


*** Variable: SAMPLING WEIGHT ***
	/* We don't require individual weight to compute the z-scores. We 
	assume all individuals in the sample have the same sample weight */
gen sw = 1
sum sw

					
/* 
For this part of the do-file we use the WHO AnthroPlus software. This is to 
calculate the z-scores for young individuals aged 15-19 years. 
Source of ado file: https://www.who.int/growthref/tools/en/
*/

*** Indicate to STATA where the igrowup_restricted.ado file is stored:	
adopath + "$path_ado/who2007_stata"

	
/* We use 'reflib' to specify the package directory where the .dta files 
containing the WHO Growth reference are stored. Note that we use strX to specify 
the length of the path in string. */		
gen str100 reflib = "$path_ado/who2007_stata"
lab var reflib "Directory of reference tables"


/* We use datalib to specify the working directory where the input STATA data
set containing the anthropometric measurement is stored. */
gen str100 datalib = "$path_out" 
lab var datalib "Directory for datafiles"


/* We use datalab to specify the name that will prefix the output files that 
will be produced from using this ado file*/
gen str30 datalab = "girl_nutri_ben" 
lab var datalab "Working file"
	

/*We now run the command to calculate the z-scores with the adofile */
who2007 reflib datalib datalab gender age_month ageunit weight height oedema sw


/*We now turn to using the dta file that was created and that contains 
the calculated z-scores to compute BMI-for-age*/
use "$path_out/girl_nutri_ben_z.dta", clear 

	
gen	z_bmi = _zbfa
replace z_bmi = . if _fbfa==1 
	/*Benin DHS 2017-18: 1 girl 15-19 years were replaced as missing 
	because she has extreme z-scores which are biologically implausible. */
lab var z_bmi "z-score bmi-for-age WHO"


*** Standard MPI indicator ***
	/*Takes value 1 if BMI-for-age is under 2 stdev below the median & 0 
	otherwise */	
gen	low_bmiage = (z_bmi < -2.0) 
replace low_bmiage = . if z_bmi==.
lab var low_bmiage "Teenage low bmi 2sd - WHO"


*** Destitution indicator ***
 	/*Takes value 1 if BMI-for-age is under 3 stdev below the median & 0 
	otherwise */	
gen	low_bmiage_u = (z_bmi < -3.0)
replace low_bmiage_u = . if z_bmi==.
lab var low_bmiage_u "Teenage very low bmi 3sd - WHO"

tab low_bmiage, miss
tab low_bmiage_u, miss


gen girl_PR=1 
	//Identification variable for girls 15-19 years in PR recode 


	//Retain relevant variables:	
keep ind_id girl_PR age_month low_bmiage*
order ind_id girl_PR age_month low_bmiage*
sort ind_id
save "$path_out/BEN17-18_PR_girls.dta", replace
	

	//Erase files from folder:
erase "$path_out/girl_nutri_ben_z.xls"
erase "$path_out/girl_nutri_ben_prev.xls"
erase "$path_out/girl_nutri_ben_z.dta"



********************************************************************************
*** Step 1.5  MR - MEN'S RECODE  
***(Eligible man 15-64 years in the household) 
********************************************************************************
/*The purpose of step 1.5 is to identify all deaths that are reported by 
eligible men.*/

use "$path_in/BJMR71FL.dta", clear 

	
*** Generate individual unique key variable required for data merging
	*** mv001=cluster number; 
	*** mv002=household number;
	*** mv003=respondent's line number
gen double ind_id = mv001*1000000 + mv002*100 + mv003 	
format ind_id %20.0g
label var ind_id "Individual ID"

duplicates report ind_id

tab mv012, miss
codebook mv201 mv206 mv207,tab (999)
	/*Benin DHS 2017-18: Fertility and mortality question was only collected 
	from men 15-64 years.*/

gen men_MR=1 	
	//Identification variable for observations in MR recode

	
keep ind_id men_MR mv003 mv005 mv012 mv201 mv206 mv207 
order ind_id men_MR mv003 mv005 mv012 mv201 mv206 mv207 
sort ind_id
save "$path_out/BEN17-18_MR.dta", replace

	
********************************************************************************
*** Step 1.6  PR - INDIVIDUAL RECODE  
*** (Boys 15-19 years in the household)
********************************************************************************

/*Benin DHS 2017-18: There is no anthropometric information for men. Hence the 
command lines under this section have been removed.*/


********************************************************************************
*** Step 1.7  PR - HOUSEHOLD MEMBER'S RECODE 
********************************************************************************

use "$path_in/BJPR71FL.dta", clear

	
*** Generate a household unique key variable at the household level using: 
	***hv001=cluster number 
	***hv002=household number
gen double hh_id = hv001*10000 + hv002 
format hh_id %20.0g
label var hh_id "Household ID"
codebook hh_id  


*** Generate individual unique key variable required for data merging using:
	*** hv001=cluster number; 
	*** hv002=household number; 
	*** hvidx=respondent's line number.
gen double ind_id = hv001*1000000 + hv002*100 + hvidx 
format ind_id %20.0g
label var ind_id "Individual ID"
codebook ind_id


sort hh_id ind_id

*******************************************************************************
*** Step 1.8 DATA MERGING 
******************************************************************************** 
 
 
*** Merging BR Recode 
*****************************************
merge 1:1 ind_id using "$path_out/BEN17-18_BR.dta"
drop _merge
erase "$path_out/BEN17-18_BR.dta"


*** Merging IR Recode 
*****************************************
merge 1:1 ind_id using "$path_out/BEN17-18_IR.dta"
tab women_IR hv117, miss col
tab ha65 if hv117==1 & women_IR ==., miss 
	//Total number of eligible women not interviewed
drop _merge
erase "$path_out/BEN17-18_IR.dta"


/*Check if the number of women in BR recode matches the number of those
who provided birth history information in IR recode. */
count if women_BR==1
count if v201!=0 & v201!=. & women_IR==1


/*Check if the number of women in BR and IR recode who provided birth history 
information matches with the number of eligible women identified by hv117. */
count if hv117==1
count if women_BR==1 | v201==0
count if (women_BR==1 | v201==0) & hv117==1
tab v201 if hv117==1, miss
tab v201 ha65 if hv117==1, miss
	/*Note: Some 2% eligible women did not provide information on their birth 
	history. This will result in missing value for the child mortality 
	indicator that we will construct later */

	
*** Merging 15-19 years: girls 
*****************************************
merge 1:1 ind_id using "$path_out/BEN17-18_PR_girls.dta"
tab girl_PR hv044 if hv105>=15 & hv105<=19 & hv104==2, miss col
drop _merge
erase "$path_out/BEN17-18_PR_girls.dta"	
	
	
*** Merging MR Recode 
*****************************************
merge 1:1 ind_id using "$path_out/BEN17-18_MR.dta"
tab men_MR hv118 if hv027==1, miss col
drop _merge
erase "$path_out/BEN17-18_MR.dta"	


*** Merging 15-19 years: boys 
*****************************************
//Benin DHS 2017-18: Anthropometric data was not collected for men.

gen age_month_b = .
lab var age_month_b "Age in months, individuals 15-19 years (boys)"	

gen	low_bmiage_b = .
lab var low_bmiage_b "Teenage low bmi 2sd - WHO (boys)"

gen	low_bmiage_b_u = .
lab var low_bmiage_b_u "Teenage very low bmi 3sd - WHO (boys)"


*** Merging child under 5 
*****************************************
merge 1:1 ind_id using "$path_out/BEN17-18_PR_child.dta"
tab hv120, miss  
tab hc13 if hv120==1, miss
drop _merge
erase "$path_out/BEN17-18_PR_child.dta"


sort ind_id


********************************************************************************
*** Step 1.9 KEEP ONLY DE JURE HOUSEHOLD MEMBERS ***
********************************************************************************
/*The Global MPI is based on de jure (permanent) household members only. As 
such, non-usual residents will be excluded from the sample. */

clonevar resident = hv102 
tab resident, miss
label var resident "Permanent (de jure) household member"

drop if resident!=1 
tab resident, miss
	/*Benin DHS 2017-18: 945 individuals (1.27%) who were non-usual residents 
	were dropped from the sample. */

	
********************************************************************************
*** Step 1.10 KEEP HOUSEHOLDS SELECTED FOR ANTHROPOMETRIC SUBSAMPLE ***
*** if relevant
********************************************************************************
/*In a number of DHS surveys, only a subsample of households were selected for 
anthropometric measure. In such cases, the Global MPI estimation is based on 
this subsample. As such, we only retain the relevant subsample of households 
for analyses. */


/*
In all households, children under 5 were weighed and measured to determine 
their nutritional status. This suggest, we may retain 100% of the sample for 
global MPI analysis in the case of Benin. 
*/
gen subsample = .
label var subsample "Households selected as part of nutrition subsample" 

	
********************************************************************************
*** Step 1.11 CONTROL VARIABLES
********************************************************************************

/* Households are identified as having 'no eligible' members if there are no 
applicable population, that is, children 0-5 years, adult women 15-49 years or 
men 15-54 years. These households will not have information on relevant 
indicators of health. As such, these households are considered as non-deprived 
in those relevant indicators. */


*** No eligible women 15-49 years 
*** for adult nutrition indicator
***********************************************
tab ha13, miss
tab ha13 if hv105>=15 & hv105<=49 & hv104==2 & hv044==1, miss
gen fem_nutri_eligible = (ha13!=.)

tab fem_nutri_eligible, miss
bysort hh_id: egen hh_n_fem_nutri_eligible = sum(fem_nutri_eligible) 	
gen	no_fem_nutri_eligible = (hh_n_fem_nutri_eligible==0)
	//Takes value 1 if the household had no eligible women for anthropometrics
lab var no_fem_nutri_eligible "Household has no eligible women for anthropometric"	
drop hh_n_fem_nutri_eligible
tab no_fem_nutri_eligible, miss


*** No eligible women 15-49 years 
*** for child mortality indicator
*****************************************
gen	fem_eligible = (hv117==1)
bysort	hh_id: egen hh_n_fem_eligible = sum(fem_eligible) 	
	//Number of eligible women for interview in the hh
gen	no_fem_eligible = (hh_n_fem_eligible==0) 									
	//Takes value 1 if the household had no eligible women for an interview
lab var no_fem_eligible "Household has no eligible women for interview"
drop fem_eligible hh_n_fem_eligible 
tab no_fem_eligible, miss


*** No eligible men 15-54 years 
*** for adult nutrition indicator (if relevant)
***********************************************
//Benin DHS 2017-18 has no male anthropometric data.
gen	male_nutri_eligible = .
gen	no_male_nutri_eligible = .
lab var no_male_nutri_eligible "Household has no eligible men for anthropometric"	


*** No eligible men 15-64 years
*** for child mortality indicator (if relevant)
*****************************************
gen	male_eligible = (hv118==1)
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
gen	child_eligible = (hv120==1) 
bysort	hh_id: egen hh_n_children_eligible = sum(child_eligible)  
	//Number of eligible children for anthropometrics
gen	no_child_eligible = (hh_n_children_eligible==0) 
	//Takes value 1 if there were no eligible children for anthropometrics
lab var no_child_eligible "Household has no children eligible for anthropometric"
drop hh_n_children_eligible
tab no_child_eligible, miss


*** No eligible women and men 
*** for adult nutrition indicator
***********************************************
/*Benin DHS 2017-18 has no male anthropometric data. We replace the eligibility 
for adults based on information from women. */
gen no_adults_eligible = (no_fem_nutri_eligible==1)
lab var no_adults_eligible "Household has no eligible women or men for anthropometrics"
tab no_adults_eligible, miss 


*** No Eligible Children and Women
*** for child and women nutrition indicator 
***********************************************
gen	no_child_fem_eligible = (no_child_eligible==1 & no_fem_nutri_eligible==1)
lab var no_child_fem_eligible "Household has no children or women eligible for anthropometric"
tab no_child_fem_eligible, miss 


*** No Eligible Women, Men or Children 
*** for nutrition indicator 
***********************************************
/*Benin DHS 2017-18 has no male anthropometric data. We replace the 
eligibility for all based on information from women and children.*/
gen no_eligibles = (no_fem_nutri_eligible==1 & no_child_eligible==1)
lab var no_eligibles "Household has no eligible women, men, or children"
tab no_eligibles, miss


sort hh_id ind_id


********************************************************************************
*** Step 1.12 RENAMING DEMOGRAPHIC VARIABLES ***
********************************************************************************

//Sample weight
	/*Note: DHS sample weight are calculated to six decimals but are presented 
	in the standard recode files without the decimal point. As such, all DHS 
	weights should be divided by 1,000,000 before applying the weights to 
	calculation or analysis. */
desc hv005
clonevar weight = hv005
replace weight = weight/1000000 
label var weight "Sample weight"


//Area: urban or rural	
desc hv025
codebook hv025, tab (5)		
clonevar area = hv025  
replace area=0 if area==2  
label define lab_area 1 "urban" 0 "rural"
label values area lab_area
label var area "Area: urban-rural"


//Relationship to the head of household 
clonevar relationship = hv101 
codebook relationship, tab (20)
recode relationship (1=1)(2=2)(3=3)(11=3)(4/10=4)(15/16=4)(12=5)(17=6)(98=.)
label define lab_rel 1"head" 2"spouse" 3"child" 4"extended family" ///
5"not related" 6"maid"
label values relationship lab_rel
label var relationship "Relationship to the head of household"
tab hv101 relationship, miss


//Sex of household member	
codebook hv104
clonevar sex = hv104 
label var sex "Sex of household member"


//Household headship
bys	hh_id: egen missing_hhead = min(relationship)
tab missing_hhead,m 
gen household_head=.
replace household_head=1 if relationship==1 & sex==1 
replace household_head=2 if relationship==1 & sex==2
bysort hh_id: egen headship = sum(household_head)
replace headship = 1 if (missing_hhead==2 & sex==1)
replace headship = 2 if (missing_hhead==2 & sex==2)
replace headship = . if missing_hhead>2
label define head 1"male-headed" 2"female-headed"
label values headship head
label var headship "Household headship"
tab headship, miss


//Age of household member
codebook hv105, tab (999)
clonevar age = hv105  
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


//Marital status of household member
clonevar marital = hv115 
codebook marital, tab (10)
recode marital (0=1)(1=2)(8=.)
label define lab_mar 1"never married" 2"currently married" 3"widowed" ///
4"divorced" 5"not living together"
label values marital lab_mar	
label var marital "Marital status of household member"
tab hv115 marital, miss


//Total number of de jure hh members in the household
gen member = 1
bysort hh_id: egen hhsize = sum(member)
label var hhsize "Household size"
tab hhsize, miss
drop member


//Subnational region
	/*The sample for the Benin DHS 2017-18 was designed to provide 
	estimates of key indicators for the country as a whole, for urban and rural 
	areas separately, and for each of the 12 administrative departments (p.2). 
	So we use "hv024" (that contains 12 departments). */   
codebook hv024, tab (99)
clonevar region = hv024
tab hv024 region, miss
lab var region "Region for subnational decomposition"
decode region, gen(temp)
replace temp =  proper(temp)
encode temp, gen(region2)
drop region temp
rename region2 region
label define lab_reg 1"Alibori" 2"Atacora" 3"Atlantique" 4"Borgou" ///
5"Collines" 6"Couffo" 7"Donga" 8"Littoral" 9"Mono" 10"Ouémé" ///
11"Plateau" 12"Zou"
label values region lab_reg


********************************************************************************
***  Step 2 Data preparation  ***
***  Standardization of the 10 Global MPI indicators 
***  Identification of non-deprived & deprived individuals  
********************************************************************************


********************************************************************************
*** Step 2.1 Years of Schooling ***
********************************************************************************

codebook hv108, tab(30)
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
	years of education for at least 2/3 of the household members aged 
	10 years and older */	
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
label var no_missing_edu "No missing edu for at least 2/3 of the HH members aged 10 years & older"		
drop temp temp2 hhs


*** Standard MPI ***
/*The entire household is considered deprived if no household member aged 
10 years or older has completed SIX years of schooling.*/
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

codebook hv121, tab (99)
clonevar attendance = hv121 
	//Please check that it corresponds 1=attending, 0=not attending
	//If 2=attended at some time:
recode attendance (2=1) 
label define lab_attend 1 "currently attending" 0 "not currently attending"
label values attendance lab_attend
label var attendance "Attended school during current school year"
codebook attendance, tab (99)
	

*** Standard MPI ***
/*The entire household is considered deprived if any school-aged 
child is not attending school up to class 8. */ 
******************************************************************* 
gen	child_schoolage = (age>=6 & age<=14)
	/*
	Note: In Benin, the official school entrance age to primary school is 
	6 years. So, age range is 6-14 (=6+8) 
	Source: "http://data.uis.unesco.org/?ReportId=163"
	Go to Education>Education>System>Official entrance age to primary education. 
	Look at the starting age and add 8. 
	*/

	
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
tab hh_child_atten, miss

/*Note: The indicator takes value 1 if ALL children in school age are attending 
school and 0 if there is at least one child not attending. Households with no 
children receive a value of 1 as non-deprived. The indicator has a missing value 
only when there are all missing values on children attendance in households that 
have children in school age. */


	
*** Destitution MPI ***
/*The entire household is considered deprived if any school-aged 
child is not attending school up to class 6. */ 
******************************************************************* 
gen	child_schoolage_6 = (age>=6 & age<=12) 
	/*Note: In Benin, the official school entrance age is 6 years.  
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
tab hh_child_atten_u, miss


********************************************************************************
*** Step 2.3 Nutrition ***
********************************************************************************


********************************************************************************
*** Step 2.3a Adult Nutrition ***
********************************************************************************

lookfor body mass

foreach var in ha40 {
			 gen inf_`var' = 1 if `var'!=.
			 bysort sex: tab age inf_`var' 
			 /* Check whether the sample covered is restricted to the 
			 reproductive age group. If the age deviates from the usual 
			 reproductive age gorup, then please note down the age group that 
			 is covered for women and for men. 
			 
			 Benin DHS 2017-18 has anthropometric data only for women 
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


*** BMI Indicator for Men 15-59 years ***
******************************************************************* 
	//Note: Benin DHS 2017-18 has no anthropometric data for men. 
	
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
*** 			     and BMI for individuals 20-54 years ***
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


*** Harmonised MPI *** 
	/*For this country, we retain only child under 5 nutrition, 
	so it is comparable across the survey years.*/
************************************************************************
gen	hh_nutrition_uw_st_c = 1
replace hh_nutrition_uw_st_c = 0 if hh_no_uw_st==0
replace hh_nutrition_uw_st_c = . if hh_no_uw_st==.
replace hh_nutrition_uw_st_c = 1 if no_child_eligible==1   		
lab var hh_nutrition_uw_st_c "HH has no individuals malnourished"
tab hh_nutrition_uw_st_c, miss

gen	hh_nutrition_uw_st_u_c = 1
replace hh_nutrition_uw_st_u_c = 0 if hh_no_uw_st_u==0
replace hh_nutrition_uw_st_u_c = . if hh_no_uw_st_u==.
replace hh_nutrition_uw_st_u_c = 1 if no_child_eligible==1   
lab var hh_nutrition_uw_st_u_c "DST: HH has no individuals malnourished"
tab hh_nutrition_uw_st_u_c, miss


********************************************************************************
*** Step 2.4 Child Mortality ***
********************************************************************************
	
codebook v206 v207 mv206 mv207
	/*v206 or mv206: number of sons who have died 
	  v207 or mv207: number of daughters who have died */
	
egen temp_f = rowtotal(v206 v207), missing
	//Total child mortality reported by eligible women
replace temp_f = 0 if v201==0
	//This line replaces women who have never given birth	
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

egen child_mortality = rowmax(child_mortality_f child_mortality_m)
lab var child_mortality "Total child mortality within household"
tab child_mortality, miss	

		
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
/*Members of the household are considered 
deprived if the household has no electricity */
***************************************************
clonevar electricity = hv206 
codebook electricity, tab (9)
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

desc hv205 hv225
clonevar toilet = hv205  

clonevar shared_toilet = hv225
codebook shared_toilet, tab(99)  

	
*** Standard MPI ***
/*Members of the household are considered deprived if the household's 
sanitation facility is not improved (according to the SDG guideline) 
or it is improved but shared with other households*/
********************************************************************

codebook toilet, tab(99)

gen	toilet_mdg = ((toilet<23 | toilet==41) & shared_toilet!=1) 
	/*Household is assigned a value of '1' if it uses improved sanitation and 
	does not share toilet with other households  */
	
replace toilet_mdg = 0 if (toilet<23 | toilet==41) & shared_toilet==1   
	/*Household is assigned a value of '0' if it uses improved sanitation 
	but shares toilet with other households  */	
	
replace toilet_mdg = 0 if toilet == 14 | toilet == 15
	/*Household is assigned a value of '0' if it uses non-improved sanitation: 
	"flush to somewhere else" and "flush don't know where"  */	

replace toilet_mdg = . if toilet==.  | toilet==99
	//Household is assigned a value of '.' if it has missing information 	
	
lab var toilet_mdg "Household has improved sanitation"
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

desc hv201 hv204 hv202
clonevar water = hv201  
clonevar timetowater = hv204  
clonevar ndwater = hv202  	
tab hv202 if water==71, miss 	
tab hv202 if water==72, miss 	
/*Households using bottled water are only considered to be using 
improved water when they use water from an improved source for cooking and 
personal hygiene. This is because the quality of bottled water is not known.*/	


*** Standard MPI ***
/* Members of the household are considered deprived if the household 
does not have access to improved drinking water (according to the SDG 
guideline) or safe drinking water is at least a 30-minute walk from 
home, roundtrip */
********************************************************************
codebook water, tab(99)
gen	water_mdg = 1 if water==11 | water==12 | water==13 | water==14 | ///
					 water==21 | water==31 | water==41 | water==51 | ///
					 water==71 | water==72  
	/*Non deprived if water is piped into dwelling, piped to yard/plot, piped to 
	neighbour, public tap/standpipe, tube well or borehole, protected well, 
	  protected spring, rainwater, bottled water */
	
replace water_mdg = 0 if water==32 | water==42 | water==43 | ///
						 water==61 | water==62 | water==96 
	/*Deprived if it is unprotected well, unprotected spring, tanker truck
	  surface water (river/lake, etc), cart with small tank, other */

codebook timetowater, tab(9999)	
*tab water if timetowater==998
replace water_mdg = 0 if water_mdg==1 & timetowater >= 30 & timetowater!=. & ///
						 timetowater!=996 & timetowater!=998 
	/*Deprived if water source is 30 minutes or more from home, roundtrip. 
	Please check the value assigned to 'in premises'. If this is different from 
	996, add to the condition accordingly */

replace water_mdg = . if water==. | water==99
replace water_mdg = 0 if water==71 & ///
						(ndwater==32 | ndwater==42 | ndwater==43 | /// 
						 ndwater==61 | ndwater==62 | ndwater==96)
replace water_mdg = 0 if water==72 & ///
						(ndwater==32 | ndwater==42 | ndwater==43 | /// 
						 ndwater==61 | ndwater==62 | ndwater==96)						 
	/*Households using bottled water or sachet water for drinking are classified 
	as using an improved or unimproved source according to their water source 
	for non-drinking activities	*/
lab var water_mdg "Household has drinking water with MDG standards (considering distance)"
tab water water_mdg, miss


*** Destitution MPI ***
/* Members of the household is identified as destitute if household 
does not have access to safe drinking water, or safe water is more 
than 45 minute walk from home, round trip.*/
********************************************************************
gen	water_u = .
replace water_u = 1 if water==11 | water==12 | water==13| water==14 | ///
					   water==21 | water==31 | water==41 | water==51 | ///
					   water==71 | water==72 
						   
replace water_u = 0 if water==32 | water==42 | water==43 | ////
					   water==61 | water==62 | water==96
						   
replace water_u = 0 if water_u==1 & timetowater>45 & timetowater!=. & ///
					   timetowater!=995 & timetowater!=996 & ///
					   timetowater!=998 & timetowater!=999
						   
replace water_u = . if water==. | water==99

replace water_u = 0 if water==71 & ///
					   (ndwater==32 | ndwater==42 | ndwater==43 | /// 
					    ndwater==61 | ndwater==62 | ndwater==96) 
						
replace water_u = 0 if water==72 & ///
						(ndwater==32 | ndwater==42 | ndwater==43 | /// 
						 ndwater==61 | ndwater==62 | ndwater==96)						
						  
lab var water_u "Household has drinking water with MDG standards (45 minutes distance)"
tab water water_u, miss


********************************************************************************
*** Step 2.8 Housing ***
********************************************************************************

/* Members of the household are considered deprived if the household 
has a dirt, sand or dung floor */
clonevar floor = hv213 
codebook floor, tab(99)
gen	floor_imp = 1
replace floor_imp = 0 if floor<=12 | floor==96  
	//Deprived if mud/earth, sand, dung, other 	
replace floor_imp = . if floor==. | floor==99 
lab var floor_imp "Household has floor that it is not earth/sand/dung"
tab floor floor_imp, miss		


/* Members of the household are considered deprived if the household has roof 
made of natural or rudimentary materials. We followed the report's definitions
of natural and rudimentary materials. */
clonevar wall = hv214 
codebook wall, tab(99)	
gen	wall_imp = 1 
replace wall_imp = 0 if wall<=26 | wall==96  
	/*Deprived if no wall, cane/palms/trunk, mud/dirt, 
	grass/reeds/thatch, pole/bamboo with mud, stone with mud, plywood,
	cardboard, carton/plastic, uncovered adobe, canvas/tent, 
	unburnt bricks, reused wood, other */	
replace wall_imp = . if wall==. | wall==99 
lab var wall_imp "Household has wall that it is not of low quality materials"
tab wall wall_imp, miss	
	

/* Members of the household are considered deprived if the household has roof 
made of natural or rudimentary materials. We followed the report's definitions
of natural and rudimentary materials. */
clonevar roof = hv215
codebook roof, tab(99)		
gen	roof_imp = 1  
replace roof_imp = 0 if roof<=24 | roof==96 
	/*Deprived if no roof, thatch/palm leaf, mud/earth/lump of earth, 
	sod/grass, plastic/polythene sheeting, rustic mat, cardboard, 
	canvas/tent, wood planks/reused wood, unburnt bricks, other */	
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
clonevar cookingfuel = hv226


*** Standard MPI ***
/* Members of the household are considered deprived if the 
household uses solid fuels and solid biomass fuels for cooking. */
*****************************************************************
codebook cookingfuel, tab(99)
gen	cooking_mdg = 1
replace cooking_mdg = 0 if cookingfuel>5 & cookingfuel<95 
replace cooking_mdg = . if cookingfuel==. | cookingfuel==99
lab var cooking_mdg "Household uses clean fuels for cooking"
	/* Deprived if: coal/lignite, charcoal, wood, straw/shrubs/grass, 
					agricultural crop, animal dung */			 
tab cookingfuel cooking_mdg, miss	

	/*Note that in Benin DHS 2017-18, the category 'other' cooking fuel is not 
	identified as solid fuel in the report. Hence this particular category is 
	identified as 'non-deprived' */

	
*** Destitution MPI ***
*** (same as standard MPI) ***
****************************************
gen	cooking_u = cooking_mdg
lab var cooking_u "Household uses clean fuels for cooking"


********************************************************************************
*** Step 2.10 Assets ownership ***
********************************************************************************
/*Assets that are included in the global MPI: Radio, TV, telephone, bicycle, 
motorbike, refrigerator, car, computer and animal cart */


*** Television/LCD TV/plasma TV/color TV/black & white tv
lookfor tv television plasma lcd	
codebook hv208
clonevar television = hv208 
lab var television "Household has television"	

	
***	Radio/walkman/stereo/kindle
lookfor radio walkman stereo
codebook hv207
clonevar radio = hv207 
lab var radio "Household has radio"	

	
***	Handphone/telephone/iphone/mobilephone/ipod
lookfor telephone téléphone mobilephone ipod
codebook hv221 hv243a
clonevar telephone = hv221
replace telephone=1 if telephone!=1 & hv243a==1	
	//hv243a=mobilephone. Combine information on telephone and mobilephone.	
tab hv243a hv221 if telephone==1,miss
lab var telephone "Household has telephone (landline/mobilephone)"	

	
***	Refrigerator/icebox/fridge
lookfor refrigerator réfrigérateur
codebook hv209
clonevar refrigerator = hv209 
lab var refrigerator "Household has refrigerator"


***	Car/van/lorry/truck
lookfor car voiture truck van
codebook hv212
clonevar car = hv212  
lab var car "Household has car"		
		
***	Bicycle/cycle rickshaw
lookfor bicycle bicyclette
codebook hv210
clonevar bicycle = hv210 
lab var bicycle "Household has bicycle"	


***	Motorbike/motorized bike/autorickshaw
lookfor motorbike moto
codebook hv211
clonevar motorbike = hv211 
lab var motorbike "Household has motorbike"	

	
***	Computer/laptop/tablet
lookfor computer ordinateur laptop ipad tablet
codebook hv243e
clonevar computer = hv243e
lab var computer "Household has computer"
	
***	Animal cart
lookfor cart 
codebook hv243c
clonevar animal_cart = hv243c
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

	
	//Retain year, month & date of interview:
desc hv007 hv006 hv008
clonevar year_interview = hv007 	
clonevar month_interview = hv006 
clonevar date_interview = hv008
 
		
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
recode hh_mortality_u18_5y  (0=1)(1=0) , gen(d_cm_01)
recode hh_nutrition_uw_st_c (0=1)(1=0) , gen(d_nutr_01)
recode hh_child_atten 		(0=1)(1=0) , gen(d_satt_01)
recode hh_years_edu6 		(0=1)(1=0) , gen(d_educ_01)
recode electricity 			(0=1)(1=0) , gen(d_elct_01)
recode water_mdg 			(0=1)(1=0) , gen(d_wtr_01)
recode toilet_mdg 			(0=1)(1=0) , gen(d_sani_01)
recode housing_1 			(0=1)(1=0) , gen(d_hsg_01)
recode cooking_mdg 			(0=1)(1=0) , gen(d_ckfl_01)
recode hh_assets2 			(0=1)(1=0) , gen(d_asst_01)	
	

recode hh_mortality_u         (0=1)(1=0) , gen(dst_cm_01)
recode hh_nutrition_uw_st_u_c (0=1)(1=0) , gen(dst_nutr_01)
recode hh_child_atten_u 	  (0=1)(1=0) , gen(dst_satt_01)
recode hh_years_edu_u 		  (0=1)(1=0) , gen(dst_educ_01)
recode electricity_u		  (0=1)(1=0) , gen(dst_elct_01)
recode water_u	 			  (0=1)(1=0) , gen(dst_wtr_01)
recode toilet_u 			  (0=1)(1=0) , gen(dst_sani_01)
recode housing_u 			  (0=1)(1=0) , gen(dst_hsg_01)
recode cooking_u			  (0=1)(1=0) , gen(dst_ckfl_01)
recode hh_assets2_u 		  (0=1)(1=0) , gen(dst_asst_01) 


	/*In this survey, the harmonised 'region_01' variable is the 
	same as the standardised 'region' variable.*/	
clonevar region_01 = region  

 
*** Generate coutry and survey details for estimation ***
char _dta[cty] "Benin"
char _dta[ccty] "BEN"
char _dta[year] "2017-2018" 	
char _dta[survey] "DHS"
char _dta[ccnum] "204"
char _dta[type] "micro"


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

	
*** Sort, compress and save data for estimation ***
sort ind_id
compress
la da "Micro data for `_dta[ccty]' (`_dta[ccnum]') from `c(current_date)' (`c(current_time)')."
save "$path_out/ben_dhs17-18.dta", replace 

	