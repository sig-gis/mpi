********************************************************************************
/* Adapted from:
Oxford Poverty and Human Development Initiative (OPHI), University of Oxford. 
2023 Global Multidimensional Poverty Index - Cambodia DHS 2021-2022
[STATA do-file]. Available from http://ophi.org.uk/  

For further queries, contact: ophi@qeh.ox.ac.uk */
********************************************************************************

clear all 
set more off
*set maxvar 10000


cd "C:\Users\tianc\OneDrive\Documents\SIG\DISES\code\MPI"
*** Working Folder Path ***
global path_in "../../data/DHS/Cambodia/STATA" 	  
global path_out "../../data/MPI/khm_dhs2122_test"
global path_ado "ado"

********************************************************************************
*** Cambodia DHS 2021-22 ***
********************************************************************************

********************************************************************************
**# Step 1: Data preparation 
********************************************************************************

	
********************************************************************************
**# Step 1.1 CHILDREN UNDER 5
********************************************************************************

use "$path_in/KHPR82DT/KHPR82FL.dta", clear 


*** Generate individual unique key variable required for data merging using:
	*** hv001=cluster number; 
	*** hv002=household number; 
	*** hvidx=respondent's line number.
gen double ind_id = hv001*1000000 + hv002*100 + hvidx 
format ind_id %20.0g
duplicates report ind_id
label var ind_id "Individual ID"
codebook ind_id  // unique identifier of 85804 ppl.


tab hv120, m  // Children eligibility for height/weight and hemo  // qc: 4,499 children under 5 are eligible for measurement	
count if hc1!=.        // qc: children have data on age in months
ta hv105 if hc1!=.    // qc: all are within the 5 year age group
keep if hv120==1
count  //5,234 children under 5		


*** Check variables that WHO ado needs to calculate the z-scores:

*** Variable: SEX ***
desc hc27 hv104 			  // sex
compare hc27 hv104			 // qc: hc27 matches hv104
codebook hc27				// 1=male; 2=female 
clonevar gender = hc27


*** Variable: AGE ***
desc hc1 hc1a 					// qc: use age in days if available (previous DHS surveys use age in months)
clonevar age_days = hc1a
su age_days 					// qc: check min & max value 0 - 1826 (= 365 * 4 + 366)
codebook age_days  // no missing

gen str6 ageunit = "days"
lab var ageunit "days"


*** Variable: BODY WEIGHT (KILOGRAMS) ***
codebook hc2, ta (999)  			   // qc: body weight in kilogram (kg)
gen	weight = hc2/10 if hc2<9990 	   // qc: check out of range value 
ta hc13 hc2 if hc2>=9990, m 		   // qc: why missing	
su weight  // 2.3 - 40


*** Variable: HEIGHT (CENTIMETERS)
codebook hc3, ta (999) 				// qc: height in centimeters (cm)
gen	height = hc3/10 if hc3<9990     // qc: check out of range value   
ta hc13 hc3 if hc3>=9990, m			// qc: why missing	
su height  // 24.5 - 135


*** Variable: MEASURED STANDING/LYING DOWN ***	
codebook hc15 								 // how child was measured
gen measure = "l" if hc15==1 				 // lying down
replace measure = "h" if hc15==2 			 // standing up
replace measure = " " if hc15==0 | hc15==.   // " " if unknown
ta measure


*** Variable: OEDEMA ***
lookfor oedema  // nothing returned
gen  oedema = "n"  
	//It assumes no-one has oedema

	
*** Variable: SAMPLING WEIGHT ***
	/* We don't require individual weight to compute the z-scores of a child. 
	So we assume all children in the sample have the same sample weight */	
gen sw = 1									// sampling weight

gen weight_ch = hv005/1000000
lab var weight_ch "sample weight child under 5" 
	// In the scripts associated with some previous DHS surveys, weight_ch is defined later and not divided by 1e6, but it not used for calculation, so the inconsistency is ok.

*** Indicate to STATA where the igrowup_restricted.ado file is stored:
	***Source of ado file: http://www.who.int/childgrowth/software/en/
adopath + "$path_ado/igrowup_stata"		 	 //compute z-score

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
gen str30 datalab = "children_nutri_khm" 
lab var datalab "Working file"

// CREATE folder manually before running the igrowup_restricted command: path_out "../../data/MPI/khm_dhs2122_test"

/*We now run the command to calculate the z-scores with the adofile */
igrowup_restricted reflib datalib datalab gender age_days ///
ageunit weight height measure oedema sw

/*We now turn to using the dta file that was created and that contains 
the calculated z-scores to create the child nutrition variables following WHO 
standards */
use "$path_out/children_nutri_khm_z_rc.dta", clear 


*** Standard MPI indicator ***
	//Takes value 1 if the child is under 2 stdev below the median & 0 otherwise
sum _zwei  //  -7.62 - 37.4
gen	underweight = (_zwei < -2.0) 
replace underweight = . if _zwei == . | _fwei==1
lab var underweight  "Child is undernourished (weight-for-age) 2sd - WHO"
ta underweight [aw=weight_ch],m 			// qc: matches report (p.234)  // 15.84% undernourished


gen stunting = (_zlen < -2.0)
replace stunting = . if _zlen == . | _flen==1
lab var stunting "Child is stunted (length/height-for-age) 2sd - WHO"
ta stunting [aw=weight_ch],m				// qc: matches report (p.234)  // 20.99% stunted


gen wasting = (_zwfl < - 2.0)
replace wasting = . if _zwfl == . | _fwfl == 1
lab var wasting  "Child is wasted (weight-for-length/height) 2sd - WHO"
ta wasting [aw=weight_ch],m  // 9.15% wasted


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
	/* 77 children were replaced as missing because they have extreme 
	z-scores which are biologically implausible. */
  
gen child_PR=1
	//Identification variable for children under 5 in PR recode
count


keep ind_id child_PR weight_ch underweight* stunting* wasting* 
order ind_id child_PR weight_ch underweight* stunting* wasting*
sort ind_id
save "$path_out/KHM21-22_PR_child.dta", replace


	// erase files
//erase "$path_out/children_nutri_khm_z_rc.xls" 				
//erase "$path_out/children_nutri_khm_prev_rc.xls"
//erase "$path_out/children_nutri_khm_z_rc.dta"


********************************************************************************
**# Step 1.2  BIRTH HISTORY
********************************************************************************
/*The purpose of step 1.2 is to identify children of any age who died in 
the last 5 years prior to the survey date.*/

use "$path_in/KHBR82DT/KHBR82FL.dta", clear


*** Generate individual unique key variable required for data merging
*** v001=cluster number;  
*** v002=household number; 
*** v003=respondent's line number
gen double ind_id = v001*1000000 + v002*100 + v003 
format ind_id %20.0g
label var ind_id "Individual ID"



desc b3 b7	// b3: date of birth (cmc) - none missing; b7: age at death (months, imputed) - 32,861/34,402 missing? not dead?
gen date_death = b3 + b7			 
	//Date of death = date of birth (b3) + age at death (b7)
gen mdead_svy = v008 - date_death 	
	//Months dead from survey = Date of interview (v008) - date of death
gen ydead_svy = mdead_svy/12
	//Years dead from survey

gen age_death = b7	
lab var age_death "Age at death in months"	
ta age_death, m  // 0 - 360

codebook b5, tab (10)  // child is alive or not		 
gen child_died = 1 if b5==0
	//Redefine the coding and labels (1=child dead; 0=child alive)
replace child_died = 0 if b5==1
replace child_died = . if b5==.
label define lab_died 1 "child has died" 0 "child is alive"
lab val child_died lab_died
ta b5 child_died, m


	/*NOTE: For each woman, sum the number of children who died and compare to 
	the number of sons/daughters whom they reported have died */
bys ind_id: egen tot_child_died = sum(child_died)  
 // number of children who died for each women

egen tot_child_died_2 = rsum(v206 v207) // v206-7: sons/daughters who have died
compare tot_child_died tot_child_died_2   // qc: figures are identical


	//Identify child under 18 mortality in the last 5 years
gen child18_died = child_died
replace child18_died=0 if age_death>=216 & age_death!=.
*lab def lab_u18died 1 "child u18 has died" 0 "child is alive/died but older"
*lab val child18_died lab_u18died
ta child18_died, m	

bys ind_id: egen tot_child18_died_5y=sum(child18_died) if ydead_svy<=5
	/*Total number of children under 18 who died in the past 5 years 
	prior to the interview date */	

replace tot_child18_died_5y=0 if tot_child18_died_5y==. & ///
								 tot_child_died>=0 & tot_child_died!=.
/* note: all children who are alive or who died longer than 
5 years from the interview date are replaced as '0' */

	
replace tot_child18_died_5y=. if child18_died==1 & ydead_svy==.
// note: replaced as '.' if there is no data on when the child died  

ta tot_child_died tot_child18_died_5y, m  // 0-7 vs 0-2

bys ind_id: egen childu18_died_per_wom_5y = max(tot_child18_died_5y)
lab var childu18_died_per_wom_5y "Total child under 18 death for each women in the last 5 years (birth recode)"



bys ind_id: gen id=1 if _n==1
keep if id==1								// keep one observation per women
drop id
duplicates report ind_id 

gen women_BR = 1
	//Identification variable for observations in BR recode

keep ind_id women_BR childu18_died_per_wom_5y		// keep relevant variables
order ind_id women_BR childu18_died_per_wom_5y
sort ind_id
save "$path_out/KHM21-22_BR.dta", replace	


********************************************************************************
**# Step 1.3  INDIVIDUAL (WOMEN) 
********************************************************************************

use v001 v002 v003 v005 v012 v201 v206 v207 ///
using "$path_in/KHIR82DT/KHIR82FL.dta", clear
/*v005: sample weight
v012: Current age - respondent
v201: Total children ever born
v206: Sons who have died
v207: Daughters who have died
*/

*** Generate individual unique key variable required for data merging
*** v001=cluster number;  
*** v002=household number; 
*** v003=respondent's line number
gen double ind_id = v001*1000000 + v002*100 + v003 
format ind_id %20.0g
label var ind_id "Individual ID"
duplicates report ind_id

ta v012, m 						  // qc: age 15-49 years, match svy report (p.6)

codebook v201 v206 v207,tab (999)  // qc: check for missing values

gen women_IR = 1 
	//Identification variable for observations in IR recode


keep ind_id women_IR v003 v005 v012 v201 v206 v207 
order ind_id women_IR v003 v005 v012 v201 v206 v207 
sort ind_id
save "$path_out/KHM21-22_IR.dta", replace


********************************************************************************
**# Step 1.4  BMI-FOR-AGE (GIRLS 15-19)
********************************************************************************

use "$path_in/KHPR82DT/KHPR82FL.dta", clear 

*** Generate individual unique key variable required for data merging
gen double ind_id = hv001*1000000 + hv002*100 + hvidx 
format ind_id %20.0g
label var ind_id "Individual ID"
codebook ind_id


*** Identify anthropometric sample for girls
codebook ha13 hv105 hv104 hv027
/*ha13: Result of measurement - height/weight
hv027:  household selected for male interview
hv105: age of hh member
hv104: sex of hh member
*/
ta ha13,m 
ta ha13 if hv105>=15 & hv105<=49 & hv104==2,m 			  // qc: if sample
ta ha13 if hv105>=15 & hv105<=49 & hv104==2 & hv027==0,m  // qc: if subsample

ta ha13 if hv105>=15 & hv105<=19 & hv104==2 & hv027==0,m  // qc: 15-19 years	
keep if hv105>=15 & hv105<=19 & hv104==2 & hv027==0
count
	// 1,654 total girls of age 15-19 in hh selected not selected for male interview (= hh with anthropometric measurements)


***Variables required to calculate the z-scores to produce BMI-for-age:

*** Variable: SEX ***	
gen gender = 2						//2:female	


*** Variable: AGE ***
lookfor hv807c hv008 ha32 	
gen age_month = hv807c - ha32
lab var age_month "Age in months, individuals 15-19 years (girls)"	
su age_month
count if age_month <= 228
	/*Note: For a couple of observations, we find that the age in months is 
	beyond 228 months. In this secton, while calculating the z-scores, these 
	cases will be excluded. However, in section 2.3, we will take the BMI 
	information of these girls. */

	
*** Variable: AGE UNIT ***
gen str6 ageunit = "months" 
lab var ageunit "Months"


*** Variable: BODY WEIGHT (KILOGRAMS) ***	
codebook ha2, ta (999)   				// qc: body weight in kilogram (kg)
gen weight = ha2/10 if ha2<9990	
ta ha13 if ha2>9990, m
	/*Weight information from girls. We divide it by 10 in order to express 
	it in kilograms. Missing values or out of range are identified as "." */
su weight  // 30.4 - 96.4


*** Variable: HEIGHT (CENTIMETERS)	
codebook ha3, ta (999) 				 // qc: height in centimeters (cm)
gen height = ha3/10 if ha3<9990
ta ha13 if ha3>9990, m
	/*Height information from girls. We divide it by 10 in order to express 
	it in centimeters. Missing values or out of range are identified as "." */
su height  // 134 - 174.7


*** Variable: OEDEMA
	// We assume all individuals in the sample have no oedema
gen oedema = "n" 
	

*** Variable: SAMPLING WEIGHT ***
	/* We don't require individual weight to compute the z-scores. We 
	assume all individuals in the sample have the same sample weight */
gen sw = 1					


// Similar to Step 1.1:
adopath + "$path_ado/who2007_stata"	  		// compute z-score
gen str100 reflib = "$path_ado/who2007_stata"
lab var reflib "Directory of reference tables"
gen str100 datalib = "$path_out" 
lab var datalib "Directory for datafiles"
gen str30 datalab = "girl_nutri_khm" 
lab var datalab "Working file"

	
who2007 reflib datalib datalab gender age_month ///
ageunit weight height oedema sw


use "$path_out/girl_nutri_khm_z.dta", clear 


gen	z_bmi = _zbfa
replace z_bmi = . if _fbfa==1 
lab var z_bmi "z-score bmi-for-age WHO"


gen	low_bmiage = (z_bmi < -2.0) 					// mpi
replace low_bmiage = . if z_bmi==.
lab var low_bmiage "Teenage low bmi 2sd - WHO"


gen	low_bmiage_u = (z_bmi < -3.0) 					// destitution
replace low_bmiage_u = . if z_bmi==.
lab var low_bmiage_u "Teenage very low bmi 3sd - WHO"

ta low_bmiage, m
ta low_bmiage_u, m

gen girl_PR=1 
	//Identification variable for girls 15-19 years in PR recode 
*lab var girl_id "girls 15-19 selected for measurement" 
count  // 1654
	
keep ind_id girl_PR age_month low_bmiage*
order ind_id girl_PR age_month low_bmiage*
sort ind_id
save "$path_out/KHM21-22_PR_girls.dta", replace


	// erase files
//erase "$path_out/girl_nutri_khm_z.xls"  			
//erase "$path_out/girl_nutri_khm_prev.xls"
//erase "$path_out/girl_nutri_khm_z.dta"


********************************************************************************
**# Step 1.5  INDIVIDUAL (MEN)  
********************************************************************************

use "$path_in/KHMR82DT/KHMR82FL.dta", clear 

*** Generate individual unique key variable required for data merging	
gen double ind_id = mv001*1000000 + mv002*100 + mv003 	
format ind_id %20.0g
label var ind_id "Individual ID"
duplicates report ind_id

ta mv012, m 						   // qc: age 15-49 years


codebook mv201 mv206 mv207,tab (999)  // qc: check for missing values - None
// Total children ever born, Sons who have died, Daughters who have died

gen men_MR = 1 	
	//Identification variable for observations in MR recode
*lab var men_MR "man 15-49 recode" 

	
keep ind_id men_MR mv003 mv005 mv012 mv201 mv206 mv207 
order ind_id men_MR mv003 mv005 mv012 mv201 mv206 mv207 
sort ind_id
save "$path_out/KHM21-22_MR.dta", replace


********************************************************************************
**# Step 1.6  BMI-FOR-AGE (BOYS 15-19)
********************************************************************************

	// anthropometric data not collected for male.
	
		
********************************************************************************
**# Step 1.7  HOUSEHOLD MEMBERS 
********************************************************************************

use "$path_in/KHPR82DT/KHPR82FL.dta", clear 

*** Generate a household unique key variable at the household level using: 
	***hv001=cluster number 
	***hv002=household number
gen double hh_id = hv001*10000 + hv002 
format hh_id %20.0g
lab var hh_id "Household ID"
codebook hh_id

*** Generate individual unique key variable required for data merging using:
gen double ind_id = hv001*1000000 + hv002*100 + hvidx 
format ind_id %20.0g
lab var ind_id "Individual ID"
codebook ind_id  //  20,806 - matches report, p.6.
duplicates report ind_id 


sort hh_id ind_id


********************************************************************************
**# Step 1.8 DATA MERGING 
********************************************************************************
 
*** Merging BR Recode 
*****************************************
merge 1:1 ind_id using "$path_out/KHM21-22_BR.dta"  			 // bh recode nrow*ncol: 13,874*3
drop _merge
// erase "$path_out/KHM21-22_BH.dta"


*** Merging IR Recode 
*****************************************
merge 1:1 ind_id using "$path_out/KHM21-22_IR.dta" 				 // wom recode 19,496 rows

tab women_IR hv117, miss col  // women_IR vs eligibility for female interview: women_IR is 1 for all obs. in KHM21-22_IR.dta (except for 349 missing values tabulated in the next line), which should be the obs. eligible for female interview
tab ha65 if hv117==1 & women_IR ==., miss 
	//Reasons the 349 eligible women are not interviewed


drop _merge
// erase "$path_out/KHM21-22_WM.dta"


/*Check if the number of women in BR recode matches the number of those
who provided birth history information in IR recode. */
count if women_BR==1  // 13,874
count if v201!=0 & v201!=. & women_IR==1  // 13,874
// v201: Total children ever born


/*Check if the number of women in BR and IR recode who provided birth history 
information matches with the number of eligible women identified by hv117. */
count if hv117==1  // hv117: Eligibility for female interview, 19,845
count if women_BR==1 | v201==0  // 19,496 women in BR or has 0 child
count if (women_BR==1 | v201==0) & hv117==1  // 19,496
tab v201 if hv117==1, miss  // 349 eligible, but missing birth history (total children ever born)
tab v201 ha65 if hv117==1, miss
	/*Note: Some small percent of eligible women did not provide information on their birth 
	history. This will result in missing value for the child mortality 
	indicator that we will construct later */	

	
*** Merging 15-19 years: girls 
*****************************************
merge 1:1 ind_id using "$path_out/KHM21-22_PR_girls.dta"			// girls 15-19 1,654 rows
drop _merge
// erase "$path_out/KHM21-22_girls.dta"	
	
	
*** Merging MR Recode 
*****************************************
merge 1:1 ind_id using "$path_out/KHM21-22_MR.dta" 				 // mn recode 8,825 rows

tab men_MR hv118 if hv027==1, miss col  // men_MR=1 corresponds to eligibility for male interview; 254 eligible male have men_MR missing

drop _merge
// erase "$path_out/KHM21-22_MN.dta"	


*** Merging 15-19 years: boys 
*****************************************
	//Anthropometric data was not collected for boys 15-19 years 
gen age_month_b = .
lab var age_month_b "Age in months, individuals 15-19 years (boys)"	

gen	low_bmiage_b = .
lab var low_bmiage_b "Teenage low bmi 2sd - WHO (boys)"

gen	low_bmiage_b_u = .
lab var low_bmiage_b_u "Teenage very low bmi 3sd - WHO (boys)"


*** Merging child under 5 
*****************************************
merge 1:1 ind_id using "$path_out/KHM21-22_PR_child.dta"  			// ch recode 4,499 rows

tab hv120, miss  // # of matched obs. same as # of children eligible for height/weight and hemoglobin
tab hc13 if hv120==1, miss  // among the eligible children, 96.64% measured

drop _merge
// erase "$path_out/KHM21-22_CH.dta"


sort ind_id

save "$path_out/KHM21-22_merged.dta", replace


********************************************************************************
**# Step 1.9 USUAL HOUSEHOLD MEMBERS ***
********************************************************************************

use "$path_out/KHM21-22_merged.dta", clear


//Permanent (de jure) household members 
clonevar resident = hv102  // usual resident
codebook resident, tab (10)  // 338 no, all others yes
label var resident "Permanent (de jure) household member"

drop if resident!=1 
tab resident, miss
	/*Note: The Global MPI is based on de jure (permanent) household members 
	only. As such, non-usual residents will be excluded from the sample. */

	
********************************************************************************
**# Step 1.10 ANTHROPOMETRIC SUBSAMPLE ***
********************************************************************************


/* note: height and weight measurements was collected from 
children under five and women 15-49 years living in 50% of 
the households that was not selected for male interview. */


codebook hv027  // hv027: household selected for male interview
ta ha13 hv027,m
ta child_PR hv027,m

drop if hv027!=0  // keep 1/2 hhs not selected for male interview

gen subsample = 1
label var subsample "Households selected as part of nutrition subsample" 
tab subsample, miss	

	
********************************************************************************
**# Step 1.11 CONTROL VARIABLES
********************************************************************************

/* Households are identified as having 'no eligible' members if there are no 
applicable population, that is, children 0-5 years, adult women 15-49 years or 
adult men. These households will not have information on relevant indicators 
of health. As such, these households are considered as non-deprived in those 
relevant indicators.*/


*** No eligible women 15-49 years 
*** for adult nutrition indicator
***********************************************
ta ha13, m  // ha13: Result of measurement - height/weight
ta ha13 if hv105>=15 & hv105<=49 & hv104==2, m

gen fem_nutri_eligible = (ha13!=.)
ta fem_nutri_eligible, m  // about 3/4 ppl. not eligible
bys hh_id: egen hh_n_fem_nutri_eligible = sum(fem_nutri_eligible) 	
gen	no_fem_nutri_eligible = (hh_n_fem_nutri_eligible==0)
	//Takes value 1 if the household had no eligible women for anthropometrics
lab var no_fem_nutri_eligible "Household has no eligible women for anthropometric"
drop hh_n_fem_nutri_eligible
ta no_fem_nutri_eligible, m  // about 15% people are in households with no eligible women for anthromopetric


*** No eligible women 15-49 years 
*** for child mortality indicator
*****************************************
gen	fem_eligible = (hv117==1)  // hv117: Eligibility for female interview
bys	hh_id: egen hh_n_fem_eligible = sum(fem_eligible) 
	//Number of eligible women for interview in the hh
gen	no_fem_eligible = (hh_n_fem_eligible==0) 	
	//Takes value 1 if the household had no eligible women for an interview								
lab var no_fem_eligible "Household has no eligible women for interview"
drop fem_eligible hh_n_fem_eligible 
ta no_fem_eligible, m


*** No eligible men 
*** for adult nutrition indicator (if relevant)
***********************************************
	//Note: There is no male anthropometric data for Cambodia DHS 2021-22
gen	male_nutri_eligible = .	
gen	no_male_nutri_eligible = .
lab var no_male_nutri_eligible "Household has no eligible men for anthropometric"	


*** No eligible men 
*** for child mortality indicator (if relevant)
*****************************************
	/* In the case of Cambodia DHS 2021-22, information from men will not make a 
	difference. This is because for MPI estimation, we have restricted the 
	sample to the nutrition subsample. Recall that in a subsample half households, all men aged 15-49 were eligible to be surveyed. Hence 
	men in the 1/2 subsampled households have provided information on child 
	mortality. However, it is only in the half of households, not selected 
	for the male survey, all women 15-49 years and all children under five were 
	eligible to be measured and weighed to assess their nutritional status. 
	In other words, the subsample that has the anthropometric information from 
	children and women, does not have information on child mortality from men. 
	Hence, we identify this survey as not having child mortality information 
	from men even though the data was collected */
gen	no_male_eligible = .
lab var no_male_eligible "Household has no eligible man for interview"


*** No eligible children under 5
*** for child nutrition indicator
*****************************************
gen	child_eligible = (hv120==1)  // Children eligibility for height/weight and hemo
bys	hh_id: egen hh_n_children_eligible = sum(child_eligible) 
	//Number of eligible children for anthropometrics
gen	no_child_eligible = (hh_n_children_eligible==0) 
	//Takes value 1 if there were no eligible children for anthropometrics
lab var no_child_eligible "Household has no children eligible for anthropometric"
drop hh_n_children_eligible
ta no_child_eligible, m  // 1:0 about half:half


*** No eligible women and men 
*** for adult nutrition indicator
***********************************************
		/*There is no male anthropometric data for Cambodia DHS 2021-22. So 
		this variable is only made up of eligible adult women */
gen no_adults_eligible = (no_fem_nutri_eligible==1)  
lab var no_adults_eligible "Household has no eligible women or men for anthropometrics"
ta no_adults_eligible, m 


*** No Eligible Children and Women
*** for child and women nutrition indicator 
***********************************************
gen	no_child_fem_eligible = (no_child_eligible==1 & no_fem_nutri_eligible==1)
lab var no_child_fem_eligible "Household has no children or women eligible for anthropometric"
tab no_child_fem_eligible, miss 


*** No Eligible Women, Men or Children 
*** for nutrition indicator 
***********************************************
		/*There is no male anthropometric data for Cambodia DHS 2021-22. So 
		this variable is only made up of eligible adult women and 
		children */
gen no_eligibles = (no_fem_nutri_eligible==1 & no_child_eligible==1)
lab var no_eligibles "Household has no eligible women, men, or children"
ta no_eligibles, m


sort hh_id ind_id


********************************************************************************
**# 1.12 RELEVANT VARIABLES ***
********************************************************************************

desc hv005 hv021 hv022
/*
household sample weight (6 decimals)
primary sampling unit
sample strata for sampling errors
*/

// sample weight 
gen weight = hv005/1000000 						      
lab var weight "Sample weight"

/* Commented out to be consistent with scripts associated with previous DHS surveys

clonevar psu = hv021								
lab var psu "Primary sampling unit"

clonevar strata = hv022
lab var strata "Sample strata"

* svyset psu [pw=weight] , strata(strata)	 singleunit(centered)

*/


codebook hv025											// area: urban-rural	
recode hv025 (1=1 "urban") (2=0 "rural"), gen (area)			
lab var area "Area: urban-rural"
ta hv025 area, m

	
//Relationship to the head of household 	
codebook hv101, ta (99)
clonevar relationship = hv101
// the variable is not used in MPI, so the following lines are not inspected 
/*
recode hv101 (1=1 "head")(2=2 "spouse")(3 11=3 "child") ///
(4/10=4 "extended family")(12/15=5 "not related")(98=.), ///
gen (relationship)
lab var relationship "relationship to the head of hh"
ta hv101 relationship, m	
*/


// sex
codebook hv104												
clonevar sex = hv104
// doesn't recode sex (9=.) as in 2010 script, but ok because there's no missing value here  
lab var sex "Sex of household member"


//Household headship  // not used for MPI, so the following lines are not inspected
/*
bys	hh_id: egen missing_hhead = min(relationship)			// headship
ta missing_hhead,m 
gen household_head=.
replace household_head=1 if relationship==1 & sex==1 
replace household_head=2 if relationship==1 & sex==2
bys hh_id: egen headship = sum(household_head)
replace headship = 1 if (missing_hhead==2 & sex==1)
replace headship = 2 if (missing_hhead==2 & sex==2)
replace headship = . if missing_hhead>2
lab def head 1"male-headed" 2"female-headed"
lab val headship head
lab var headship "household headship"
ta headship, m
*/


//Age of household member
codebook hv105, ta (999)
clonevar age = hv105  
replace age = . if age>=98  // 98  don't know, no missing
lab var age "Age of household member"


//Age group 
recode age (0/4 = 1 "0-4")(5/9 = 2 "5-9")(10/14 = 3 "10-14") ///
		   (15/17 = 4 "15-17")(18/59 = 5 "18-59")(60/max=6 "60+"), gen(agec7)
lab var agec7 "age groups (7 groups)"	
	   
recode age (0/9 = 1 "0-9") (10/17 = 2 "10-17")(18/59 = 3 "18-59") ///
		   (60/max=4 "60+"), gen(agec4)
lab var agec4 "age groups (4 groups)"

recode age (0/17 = 1 "0-17") (18/max = 2 "18+"), gen(agec2)		 		   
lab var agec2 "age groups (2 groups)"


 
codebook hv115, ta (9) 									 // marital status
recode hv115 (0=1 "never married") ///
(1=2 "currently married") (3=3 "widowed") ///
(4=4 "divorced"), gen (marital)	
lab var marital "Marital status of household member"
ta hv115 marital, m


//Total number of de jure hh members in the household
gen member = 1 
bys hh_id: egen hhsize = sum(member)
lab var hhsize "Household size"
ta hhsize, m
drop member


// subnational regions		
codebook hv024, ta (99)								


gen region_raw = hv024
lab var region_raw "Region for subnational decomposition, not harmonized over time"
  	
lab def la_reg ///
1 "Banteay Meanchay" 2 "Battambang" 3 "Kampong Cham" 4 "Kampong Chhnang" ///
5 "Kampong Speu" 6 "Kampong Thom" 7 "Kampot" 8 "Kandal" 9 "Koh Kong" ///
10 "Kratie" 11 "Mondul Kiri" 12 "Phnom Penh" 13 "Preah Vihear"  ///
14 "Prey Veng" 15 "Pursat" 16 "Ratanak Kiri" 17 "Siem Reap" ///
18 "Preah Sihanouk" 19 "Stung Treng" 20 "Svay Rieng" ///
21 "Takeo" 22 "Otdar Meanchey" 23 "Kep"  24 "Pailin" 25 "Tboung Khmum" 
lab val region_raw la_reg


// subnational region, harmonised over time

recode hv024 (1=1 "Banteay Meanchay") (3 25=2 "Kampong Cham")  ///
(4=3 "Kampong Chhnang") (5=4 "Kampong Speu") (6=5 "Kampong Thom")  ///
(8=6 "Kandal") (10=7 "Kratie") (12=8 "Phnom Penh") (14=9 "Prey Veng") ///
(15=10 "Pursat")(17=11 "Siem Reap")(20=12 "Svay Rieng")(21=13 "Takeo") ///
(22=14 "Otdar Meanchey")(2 24 = 15 "Battambang & Pailin")(7 23=16 "Kampot & Kep") ///
(9 18=17 "Preah Sihanouk and Koh Kong") (13 19 =18 "Preah Vihear and Stung Treng") ///
(11 16= 19 "Mondul Kiri and Ratanak Kiri"), gen(region)

lab var region "Region for subnational decomposition"
codebook region, ta(99)

save "$path_out/KHM21-22_merged_procd.dta", replace  // proccessed


********************************************************************************
**#  Step 2 Data preparation  ***
***  Standardization of the global MPI indicators   
********************************************************************************

use "$path_out/KHM21-22_merged_procd.dta", clear 

********************************************************************************
**# Step 2.1 Years of Schooling ***
********************************************************************************

codebook hv108 hv106, ta(99)
ta hv108 hv106,m

clonevar  eduyears = hv108 if hv108 < 98  // years of educ (education completed in single years),  98  don't know
replace eduyears = . if eduyears>30
	//Recode any unreasonable years of highest education as missing value  // none here
/* Commented out to be consistent with scripts associated with previous DHS surveys

replace eduyears = 6  if hv108==98 & hv106==2      	 // check missing   
replace eduyears = 12 if hv108==98 & hv106==3 

*/
replace eduyears = . if age<=eduyears & age>0 
	// note: years of schooling is greater than age
	
replace eduyears = 0 if age<10  
	/*The variable "eduyears" was replaced with a '0' given that the criteria 
	for this indicator is household member aged 10 years or older */		
/* Commented out to be consistent with scripts associated with previous DHS surveys

replace eduyears = 0 if (age==10 | age==11) & eduyears < 6  // non-eligible age group
					
*/


	/*A control variable is created on whether there is information on 
	years of education for at least 2/3 of the household members aged 10 years 
	and older */		
gen temp = 1 if eduyears!=. & age>=10 & age!=.
bys	hh_id: egen no_missing_edu = sum(temp)
	/*Total household members who are 10 years and older with no missing 
	years of education */
gen temp2 = 1 if age>=10 & age!=.
bys hh_id: egen hhs = sum(temp2)
	//Total number of household members who are 10 years and older 
replace no_missing_edu = no_missing_edu/hhs
replace no_missing_edu = (no_missing_edu>=2/3)	
	/*Identify whether there is information on years of education for at 
	least 2/3 of the household members aged 10 years and older */
ta no_missing_edu, m							// qc: missing (0) is < 0.5% - 0.73%
lab var no_missing_edu "No missing edu for at least 2/3 of the HH members aged 10 years & older"	
drop temp temp2 hhs


*** Standard MPI ***
/*The entire household is considered deprived if no household member 
aged 10 years or older has completed SIX years of schooling.*/
******************************************************************* 
gen	years_edu6 = (eduyears>=6)  // 36.91% true
	/* The years of schooling indicator takes a value of "1" if at least someone 
	in the hh has reported 6 years of education or more */
replace years_edu6 = . if eduyears==.  // 309
bysort hh_id: egen hh_years_edu6_1 = max(years_edu6)  // 1 if at least someone..
gen	hh_years_edu6 = (hh_years_edu6_1==1)
replace hh_years_edu6 = . if hh_years_edu6_1==.
replace hh_years_edu6 = . if hh_years_edu6==0 & no_missing_edu==0 
lab var hh_years_edu6 "Household has at least one member with 6 years of edu"

tab hh_years_edu6, m  // 21.08% deprived

	
*** Destitution MPI ***
/*The entire household is considered deprived if no household member 
aged 10 years or older has completed at least one year of schooling.*/
******************************************************************* 
gen	years_edu1 = (eduyears>=1)
replace years_edu1 = . if eduyears==.
bysort	hh_id: egen hh_years_edu_u = max(years_edu1)
replace hh_years_edu_u = . if hh_years_edu_u==0 & no_missing_edu==0
lab var hh_years_edu_u "Household has at least one member with 1 year of edu"

tab hh_years_edu_u, m  // 3.44% deprived


********************************************************************************
**# Step 2.2 School Attendance ***
********************************************************************************

codebook hv121, ta (99)
recode hv121 (2=1 "currently attending") (0=0 "no"), gen (attendance)
* lab var attendance "current school year"	
ta attendance, m


*** Standard MPI ***
/*The entire household is considered deprived if any school-aged 
child is not attending school up to class 8. */ 
******************************************************************* 
gen	child_schoolage = (age>=6 & age<=14)
	/*In Cambodia, the official school entrance age is 6 years.  
	  So, age range is 6-14 (=6+8)  
	  Source: "http://data.uis.unesco.org/?ReportId=163"  */
	  
	
	/*A control variable is created on whether there is no information on 
	school attendance for at least 2/3 of the school age children */
count if child_schoolage==1 & attendance==.
	//Understand how many eligible school aged children don't have attendence info
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
tab no_missing_atten, miss  // all 1's
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
	/*If the household has been intially identified as non-deprived, but has 
	missing school attendance for at least 2/3 of the school aged children, then 
	we replace this household with a value of '.' because there is insufficient 
	information to conclusively conclude that the household is not deprived */
lab var hh_child_atten "Household has all school age children up to class 8 in school"
tab hh_child_atten, miss  // 22.47% deprived

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
	/*In Cambodia, the official school entrance age is 6 years.  
	  So, age range for destitution measure is 6-12 (=6+6) */

	
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
	/*If the household has been intially identified as deprived, but has 
	missing school attendance for at least 2/3 of the school aged children, then 
	we replace this household with a value of '.' because there is insufficient 
	information to conclusively conclude that the household is deprived */
lab var hh_child_atten_u "Household has at least one school age children up to class 6 in school"
tab hh_child_atten_u, miss  // 14.94% deprived



********************************************************************************
**# Step 2.3 Nutrition 
********************************************************************************

********************************************************************************
**# Step 2.3a bmi & bmi-for-age ***
********************************************************************************
	//Cambodia DHS 2021-22 has no anthropometric data for adult men 

// ha40 BMI
foreach var in ha40 {
			 gen inf_`var' = 1 if `var'!=.
			 bys sex: ta age inf_`var' 
			  // qc: women 15-49 years measured
			 drop inf_`var'
}

*** BMI Indicator for Women 15-49 years ***
******************************************************************* 
gen	f_bmi = ha40/100  
// Percentiles:     
// 10%       25%       50%       75%       90%
// 18.47     20.16     22.48     25.25     28.15 			
lab var f_bmi "Women's BMI"
gen	f_low_bmi = (f_bmi<18.5)
replace f_low_bmi = . if f_bmi==. | f_bmi>=99.97  // max is now 54.36
lab var f_low_bmi "BMI of women < 18.5"


gen	f_low_bmi_u = (f_bmi<17)
replace f_low_bmi_u = . if f_bmi==. | f_bmi>=99.97
lab var f_low_bmi_u "BMI of women <17"
	//Note: The BMI threshold applied for destitution is 17 instead of 18.5

*** BMI Indicator for Men 15-59 years ***
******************************************************************* 
	//Note: Cambodia DHS 2014 has no anthropometric data for men. 
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
	//to be replaced by BMI-for-age for teenagers
replace low_bmi_byage = 1 if low_bmi_byage==0 & m_low_bmi==1 
	/*Replace variable "low_bmi_byage = 1" if eligible men have low BMI. If 
	there is no male anthropometric data, then 0 changes are made.*/


/*Note: The following command replaces BMI with BMI-for-age for those between 
the age group of 15-19 by their age in months where information is available */
	//Replacement for girls: 
replace low_bmi_byage = 1 if low_bmiage==1 & age_month!=.  
// low_bmiage ("Teenage low bmi 2sd - WHO") calculated by who2007 in Step 1.4
replace low_bmi_byage = 0 if low_bmiage==0 & age_month!=.

	/*Replacements for boys - if there is no male anthropometric data for boys, 
	then 0 changes are made: */
replace low_bmi_byage = 1 if low_bmiage_b==1 & age_month_b!=.
replace low_bmi_byage = 0 if low_bmiage_b==0 & age_month_b!=.


/*Note: The following control variable is applied when there is BMI information 
for adults and BMI-for-age for teenagers.*/			
replace low_bmi_byage = . if f_low_bmi==. & m_low_bmi==. & low_bmiage==. & low_bmiage_b==. 
		
bys hh_id: egen low_bmi = max(low_bmi_byage)		
gen	hh_no_low_bmiage = (low_bmi==0)
	/*Households take a value of '1' if all eligible adults and teenagers in the 
	household has normal bmi or bmi-for-age */	
replace hh_no_low_bmiage = . if low_bmi==.			
	/*Households take a value of '.' if there is no information from eligible 
	individuals in the household */
replace hh_no_low_bmiage = 1 if no_adults_eligible==1	//no eligible adult
drop low_bmi
lab var hh_no_low_bmiage "Household has no adult with low BMI or BMI-for-age"
ta hh_no_low_bmiage, m  // 7.34% deprived

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
tab hh_no_low_bmiage_u, miss  // 1.73% deprived


********************************************************************************
**# Step 2.3b Child Nutrition: underweight, stunting & wasting
********************************************************************************

*** Child Underweight Indicator ***
************************************************************************

*** Standard MPI ***
bys hh_id: egen temp = max(underweight)  // "Child is undernourished (weight-for-age) 2sd - WHO"
gen	hh_no_underweight = (temp==0)  
	//Takes value 1 if no child in the hh is underweight 
replace hh_no_underweight = . if temp==.
replace hh_no_underweight = 1 if no_child_eligible==1
		//Households with no eligible children will receive a value of 1
lab var hh_no_underweight "Household has no child underweight - 2 stdev"
tab hh_no_underweight, miss  // 98.94% no underweight
drop temp

*** Destitution MPI  ***
bys hh_id: egen temp = max(underweight_u) 			
gen	hh_no_underweight_u = (temp==0) 	// no child is severely underweight 
replace hh_no_underweight_u = . if temp==.
replace hh_no_underweight_u = 1 if no_child_eligible==1 
lab var hh_no_underweight_u "Destitute: Household has no child underweight"
drop temp


*** Child Stunting Indicator ***
************************************************************************

*** Standard MPI ***
bys hh_id: egen temp = max(stunting)  // "Child is stunted (length/height-for-age) 2sd - WHO"
gen	hh_no_stunting = (temp==0) 
	//Takes value 1 if no child in the hh is stunted
replace hh_no_stunting = . if temp==.
replace hh_no_stunting = 1 if no_child_eligible==1 
	//Households with no eligible children will receive a value of 1
lab var hh_no_stunting "Household has no child stunted - 2 stdev"
tab hh_no_stunting, m  // 87.00% no stunting
drop temp

*** Destitution MPI  ***
bys hh_id: egen temp = max(stunting_u) 				
gen	hh_no_stunting_u = (temp==0) 				// no child is severely stunted 
replace hh_no_stunting_u = . if temp==.
replace hh_no_stunting_u = 1 if no_child_eligible==1 
lab var hh_no_stunting_u "Destitute: Household has no child stunted"
drop temp


*** Child Wasting Indicator ***
************************************************************************

*** Standard MPI ***
bys hh_id: egen temp = max(wasting)  // "Child is wasted (weight-for-length/height) 2sd - WHO"
gen	hh_no_wasting = (temp==0) 
	//Takes value 1 if no child in the hh is wasted
replace hh_no_wasting = . if temp==.
replace hh_no_wasting = 1 if no_child_eligible==1 
	//Households with no eligible children will receive a value of 1
lab var hh_no_wasting "Household has no child wasted - 2 stdev"
tab hh_no_wasting, m  // 93.26% no wasted
drop temp

*** Destitution MPI  ***
bys hh_id: egen temp = max(wasting_u) 			
gen	hh_no_wasting_u = (temp==0) 				// no child is severely wasted
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
tab hh_no_uw_st, m  // 84.19% has no uw or st


*** Destitution MPI  ***
gen hh_no_uw_st_u = 1 if hh_no_stunting_u==1 & hh_no_underweight_u==1
replace hh_no_uw_st_u = 0 if hh_no_stunting_u==0 | hh_no_underweight_u==0
replace hh_no_uw_st_u = . if hh_no_stunting_u==. & hh_no_underweight_u==.
replace hh_no_uw_st_u = 1 if no_child_eligible==1 
lab var hh_no_uw_st_u "Destitute: Household has no child underweight or stunted"	


********************************************************************************
**# Step 2.3c Household Nutrition Indicator ***
********************************************************************************

*** Standard MPI ***
/* Householders are not deprived if all eligible 
person with anthropometric measurement in the household 
are nourished; or household has no eligible person. 

Specifically, members of the household are considered deprived if the household has a 
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
tab hh_nutrition_uw_st, miss  // 78.73% not deprived


*** Destitution ***
/* Householders are not deprived if all eligible person with
anthropometric measurement in the household are not severely 
undernourished; or household has no eligible person. 

Specifically, members of the household are considered deprived if the household has a 
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
	
codebook v206 v207 mv206 mv207  // mv206 mv207 are empty
	//v206 or mv206: number of sons who have died 
	//v207 or mv207: number of daughters who have died


	//Total child mortality reported by eligible women
egen temp_f = rowtotal(v206 v207), missing
replace temp_f = 0 if v201==0  // never given birth (v201: Total children ever born)
bys	hh_id: egen child_mortality_f = sum(temp_f), missing
lab var child_mortality_f "Occurrence of child mortality reported by women"
ta child_mortality_f, m
drop temp_f

	//Total child mortality reported by eligible men	
egen temp_m = rowtotal(mv206 mv207), missing
replace temp_m = 0 if mv201==0
bysort	hh_id: egen child_mortality_m = sum(temp_m), missing
lab var child_mortality_m "Occurrence of child mortality reported by men"
tab child_mortality_m, miss
drop temp_m


// Harmonization: Exclude child mortality reported by men. Replace the following chunk of code with the one below it. Child mortality reported by men is available in 2005 and 2010, but not in 2014 and 2021-22. To harmonize the child mortality indicator across the years, child mortality reported by men is excluded from 2005 and 2010 indicators.

/*
egen child_mortality = rowmax(child_mortality_f child_mortality_m)
lab var child_mortality "Total child mortality within household reported by women & men"
tab child_mortality, miss	
*/	

clonevar child_mortality = child_mortality_f
lab var child_mortality "Total child mortality within household reported by women"
ta child_mortality, m
compare child_mortality child_mortality_f


*** Standard MPI *** 
/* Householders are not deprived if all eligible women 
in the household reported zero mortality among children 
under 18 in the last 5 years from the survey year.

Specifically, members of the household are considered deprived if women in the household 
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
ta childu18_died_per_wom_5y, m	
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

*replace childu18_died_per_wom_5y = 0 if hv115==0 & hv104==2 & hv105>=15 & hv105<=49
	/*This line replaces never-married women with 0 child death. If in your 
	country dataset, child mortality information was only collected from 
	ever-married women (check report), please activate this command line.*/	
	// (p.2) The Woman's Questionnaire was used to collect information from all eligible women age 15–49. (Child mortality information is collected in Section 2 of Woman's Questionnaire)

replace childu18_died_per_wom_5y = 0 if no_fem_eligible==1	
	/*Assign a value of "0" for:
	- individuals living in households that have non-eligible women */	
	
bys hh_id: egen childu18_mortality_5y = sum(childu18_died_per_wom_5y), missing
replace childu18_mortality_5y = 0 if childu18_mortality_5y==. & child_mortality==0
	/*After harmonization, the line makes no change. 
	Before harmonization, the line replaces all households as 0 death if women has missing value and men 
	reported no death in those households */
label var childu18_mortality_5y "Under 18 child mortality within household past 5 years reported by women"
ta childu18_mortality_5y, m		
	

gen hh_mortality_u18_5y = (childu18_mortality_5y==0)
replace hh_mortality_u18_5y = . if childu18_mortality_5y==.
lab var hh_mortality_u18_5y "Household had no under 18 child mortality in the last 5 years"
tab hh_mortality_u18_5y, miss  // 98.33% have none


*** Destitution *** 
*** (same as standard MPI) ***
************************************************************************
gen hh_mortality_u = hh_mortality_u18_5y	
lab var hh_mortality_u "Household had no under 18 child mortality in the last 5 years"	


********************************************************************************
**# Step 2.5 Electricity 
********************************************************************************

*** MPI ***
/* Householders are considered not deprived 
if the household has electricity */
****************************************
codebook hv206, ta (9)

recode hv206 (0=0 "no") (1=1 "yes") (9=.), gen (electricity)
lab var electricity "Household has electricity"
ta electricity hv206,m
tab electricity, freq  // 14.72% has no electricity

	
*** Destitution ***
*** (same as MPI) ***
****************************************
gen electricity_u = electricity
label var electricity_u "Household has electricity"


********************************************************************************
**# Step 2.6 Sanitation ***
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

codebook hv205, ta(99) 	// Type of toilet facility 
/* Toilet facility categories in survey questionnaire are the same as those in 2014. Output of this line shows the coding and labels are the same as well, except there is an "other" category here coded as 96 in place of a missing (.) category in 2014. "Other" is considered non-improved to be consistent with 2010.
*/
clonevar toilet = hv205

codebook hv225  // Share toilet with other households
	//0=no;1=yes;.=missing
clonevar shared_toilet = hv225 

*** MPI ***
/* Householders are not deprived if the household has improved 
sanitation facilities that are not shared with other households. */
********************************************************************
codebook toilet, tab(30) 
	/*Note: In Cambodia, the report considers the category other open-response 
	field. But we consider it as non-improved to be consistent with the 
	indicator for destitution below */ 

gen	toilet_mdg = ((toilet<23 | toilet==41) & shared_toilet!=1) 
	/*Household is assigned a value of '1' if it uses improved sanitation and 
	does not share toilet with other households  */
	// '0' is assigned to all other households
	
replace toilet_mdg = 0 if (toilet<23 | toilet==41)  & shared_toilet==1   
	/*Household is assigned a value of '0' if it uses improved sanitation 
	but shares toilet with other households  */	
	// 0 real changes made

replace toilet_mdg = 0 if toilet == 14 | toilet == 15
	/*Household is assigned a value of '0' if it uses non-improved sanitation: 
	"flush to somewhere else" and "flush don't know where"  */	

replace toilet_mdg = . if toilet==.  | toilet==99  // 99 is handled in the code 1 line above in 2010 script, but there's no 99 in the 2014/2021-22 data, so the inconsistency is ok, 2005 script should follow 2010 script if there's 99
	//Household is assigned a value of '.' if it has missing information 	
	
lab var toilet_mdg "Household has improved sanitation with MDG Standards"
tab toilet toilet_mdg, miss


*** Destitution MPI ***
/* Householders are not deprived if the 
household has sanitation facilities. */
/* Specifically, members of the household are considered deprived if household practises 
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
**# Step 2.7 Drinking Water 
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

	/* Note: To be consistent with prior surveys whose observation on the source of drinking water and the time it takes to get the water are available only for dry and wet seasons, we construct the drinking water variable using both hv201 and sh101. Household is identified as deprived if either variable indicates a non-improved category, or they walked more than 30 minutes according to either hv204 or sh104e. */


clonevar water1 = hv201
clonevar water2 = sh101

clonevar timetowater1 = hv204  
clonevar timetowater2 = sh104e

codebook water1, tab(30)
codebook water2, tab(30)

tab timetowater2, miss nolabel
tab timetowater2, miss nolabel
codebook timetowater*, tab (9999)

/*Some DHS might have the variable non-drinking water. Please try looking for it 
as it will affect the poverty indicator. */
clonevar ndwater = hv202  
	//Cambodia DHS 2021-22 has observation for non-drinking water, but it is not used for consistency with prior surveys.
	

*** Standard MPI ***
/* Members of the household are considered deprived if the household 
does not have access to improved drinking water (according to the SDG 
guideline) or safe drinking water is at least a 30-minute walk from 
home, roundtrip */
********************************************************************
gen	water_mdg = 1 if water1==11 | water1==12 | water1==14 | ///
					 water1==21 | water1==41 | ///
					 water1==51 | water1==71 | ///
					 water2==11 | water2==12 | water2==14 | ///
					 water2==21 | water2==41 | ///
					 water2==51 | water2==71 		
	/*Non deprived if water is piped into dwelling, piped to yard/plot, 
	  public tap/standpipe, tube well or borehole, protected well, 
	  rainwater, bottled water */
/* unstats.un.org: piped water into 
dwelling, yard or plot; public taps or standpipes; boreholes or tubewells; 
protected dug wells; protected springs; packaged water; delivered water and 
rainwater */

/* Protected spring (31) and piped to neighbor (13) are considered non-improved for harmonization purpose. */
 

replace water_mdg = 0 if water1==13 | water1==31 | water1==32 | water1==42 | water1==43 | ///
						 water1==61 | water1==62 | water1==96 | ///
						 water2==13 | water2==31 | water2==32 | water2==42 | water2==43 | ///
						 water2==61 | water2==62 | water2==96 				 
	/*Deprived if it is piped to neighbor, unprotected well, protected spring, unprotected spring, tanker truck
	  surface water (river/lake, etc), cart with small tank, other */
		
replace water_mdg = 0 if (water_mdg==1 & timetowater1 >= 30 ///
						  & timetowater1!=. ///
						  & timetowater1!=996 /// on premises
						  & timetowater1!=998) /// DK
						  | (water_mdg==1 & timetowater2 >= 30 ///
						  & timetowater2!=. ///
						  & timetowater2!=996 ///
						  & timetowater2!=998)
	//Deprived if water is at more than 30 minutes' walk (roundtrip) 

replace water_mdg = . if water1==. & water2==. 
// 999 & 99 are handled in the 2 lines of code above in 2010 script, but there's no 999/99 in the 2014/2021-22 data, so the inconsistency is ok, 2005 script should follow 2010 script if there's 999/99
lab var water_mdg "Household has drinking water with MDG standards (considering distance)"
tab water_mdg, miss  // 27.20% deprived


*** Destitution MPI ***
/* Members of the household is identified as destitute if household 
does not have access to safe drinking water, or safe water is more 
than 45 minute walk from home, round trip.*/
********************************************************************
gen	water_u = 1 if   water1==11 | water1==12 | water1==14 | ///
					 water1==21 | water1==41 | ///
					 water1==51 | water1==71 | ///
					 water2==11 | water2==12 | water2==14 | ///
					 water2==21 | water2==41 | ///
					 water2==51 | water2==71 		
	
replace water_u = 0 if   water1==13 | water1==31 | water1==32 | water1==42 | water1==43 | ///
						 water1==61 | water1==62 | water1==96 | ///
						 water2==13 | water2==31 | water2==32 | water2==42 | water2==43 | ///
						 water2==61 | water2==62 | water2==96 				 

replace water_u = 0 if   (water_u==1 & timetowater1 > 45 ///
						  & timetowater1!=. ///
						  & timetowater1!=996 ///
						  & timetowater1!=998) ///
						  | (water_u==1 & timetowater2 > 45 ///
						  & timetowater2!=. ///
						  & timetowater2!=996 ///
						  & timetowater2!=998)

replace water_u = . if water1==. & water2==. 	
// same comment about 999 and 99 as in Standard MPI	
lab var water_u "Household has drinking water with MDG standards (45 minutes distance)"
tab water_u, miss  //  25.81% deprived


********************************************************************************
**# Step 2.8 Housing ***
********************************************************************************

/* Members of the household are considered deprived if the household 
has a dirt, sand or dung floor */
clonevar floor = hv213
codebook floor, tab(99)  // numeric codes similar to those in 2014, except the addition of "carpet" coded as 35 and "other" as 96
gen	floor_imp = 1
replace floor_imp = 0 if floor<=12 | floor==96  
	//Deprived if mud/earth, sand, dung, other 	
replace floor_imp = . if floor==. | floor==99 
lab var floor_imp "Household has floor that it is not earth/sand/dung"
tab floor floor_imp, miss		


/* Members of the household are considered deprived if the household has walls 
made of natural or rudimentary materials */
clonevar wall = hv214 
codebook wall, tab(99)
gen	wall_imp = .  // not needed as it is excluded for harmonization purposes
lab var wall_imp "Household has wall that it is not of low quality materials"
tab wall wall_imp, miss	
	
	
/* Members of the household are considered deprived if the household has roof 
made of natural or rudimentary materials */
clonevar roof = hv215
codebook roof, tab(99)		
gen	roof_imp = 1 
replace roof_imp = 0 if roof<=24 | roof==32 | roof==96  // numeric codes correspond to those in questionnaire
	/*Deprived if no roof, thatch/palm leaf, mud/earth/lump of earth, 
	sod/grass, plastic/polythene sheeting, rustic mat, cardboard, 
	canvas/tent, wood planks/reused wood, unburnt bricks, other */	
	/* Harmonization: also deprived if wood (roof==32). Wood is available as an option of roof material in 2010, 2014, and 2021-22, but not 2005. Households with wood roofs in 2005 might have been classified as having "other" roof materials (roof==96, which is considered unimproved). To harmonize the housing indicator across the three years, wood is considered an unimproved roof material in 2010, 2014, and 2021-22.*/
replace roof_imp = . if roof==. | roof==99 	
lab var roof_imp "Household has roof that it is not of low quality materials"
tab roof roof_imp, miss


*** Standard MPI ***
/* Members of the household is deprived in housing if the roof, 
floor OR walls are constructed from low quality materials.*/
**************************************************************
gen housing_1 = .
lab var housing_1 "Household has roof, floor & walls that it is not low quality material"
tab housing_1, miss


*** Standard MPI Customized ***
/* Members of the household is deprived in housing if the roof OR
floor are constructed from low quality materials.*/
**************************************************************
gen housing_no_wall = 1
replace housing_no_wall = 0 if floor_imp==0 | roof_imp==0
replace housing_no_wall = . if floor_imp==. & roof_imp==.
lab var housing_no_wall "Household has roof & floor that it is not low quality material"
tab housing_no_wall, miss  // 8.87% deprived


*** Destitution MPI ***
/* Members of the household is deprived in housing if two out 
of three components (roof and walls; OR floor and walls; OR 
roof and floor) the are constructed from low quality materials. */
**************************************************************
gen housing_u = .
lab var housing_u "Household has one of three aspects(either roof,floor/walls) that is not low quality material"
tab housing_u, miss


********************************************************************************
**# Step 2.9 Cooking Fuel 
********************************************************************************
/*
Solid fuel are solid materials burned as fuels, which includes coal as well as 
solid biomass fuels (wood, animal dung, crop wastes and charcoal). 

Source: 
https://apps.who.int/iris/bitstream/handle/10665/141496/9789241548885_eng.pdf
*/
	
*** MPI ***
/* Householders are considered not deprived if the 
household uses non-solid fuels for cooking. */
*****************************************************************
clonevar cookingfuel = hv226  
codebook cookingfuel, ta (99)  // numeric codes don't correspond to those in
// the questionnaire, check their labels
gen	cooking_mdg = 1
replace cooking_mdg = 0 if cookingfuel>5 & cookingfuel<95 
replace cooking_mdg = . if cookingfuel==. | cookingfuel==99
lab var cooking_mdg "Household has cooking fuel by MDG standards"
	/* Non deprived if: "electricity", "solar energy", "lpg", "natural gas", "biogas", 
						"kerosene" , "no food cooked in household", "other"
	   Deprived if: "coal/lignite", "charcoal", "wood", "straw/shrubs/grass" 
					"agricultural crop", "animal dung", "garbage/plastic" */			 
tab cookingfuel cooking_mdg, miss	

	/*Note that in Cambodia DHS 2021-22, the category 'other' cooking fuel is not 
	identified either as solid fuel or non-solid fuel. Hence this particular 
	category is identified as 'non-deprived' */
	

*** Destitution MPI ***
*** (same as standard MPI) ***
****************************************
gen	cooking_u = cooking_mdg
lab var cooking_u "Household uses clean fuels for cooking"	

********************************************************************************
**# Step 2.10 Assets ***
********************************************************************************
/* Members of the household are considered deprived if the household does not 
own more than one of: radio, TV, telephone, bike, motorbike or refrigerator and 
does not own a car or truck. */
/* The list for 2021-22 should be: radio, TV, telephone (including mobile & non-mobile telephone info), refrigerator, bike, motorbike, refrigerator, computer or animal cart*/

	//Check that for standard assets in living standards: "no"==0 and yes=="1", none missing
codebook hv208 hv207 hv221 hv243a hv209 hv212 hv210 hv211 hv243c 

clonevar television = hv208 
gen bw_television = .  // not generated in 2010 script, but the variable is not used, so the inconsistency is ok
clonevar radio = hv207 
clonevar telephone = hv221  // 223/43,035 have (land-line) telephone, the rest don't
clonevar landline = hv221
clonevar mobiletelephone = hv243a  //  38,817/43,035 have mobile, the rest don't	
clonevar refrigerator = hv209 
clonevar car = hv212  // car/truck  	
clonevar bicycle = hv210 
clonevar motorbike = hv211 
gen computer=.
clonevar animal_cart = hv243c

	//No missing value, so no change
foreach var in television radio telephone mobiletelephone refrigerator ///
			   car bicycle motorbike computer animal_cart {
replace `var' = . if `var'==9 | `var'==99 | `var'==8 | `var'==98 
}


// Harmonization: Exclude non-mobile telephone (landline). Replace the following chunk of code with the one below it. Landline is available in 2000, 2010, 2014 and 2021-22, but not 2005. To harmonize the asset indicator across the five years, landline is excluded from 2000, 2010, 2014 and 2021-22 indicators.

/*
	//Combine information on telephone and mobiletelephone
replace telephone=1 if telephone==0 & mobiletelephone==1
replace telephone=1 if telephone==. & mobiletelephone==1
// telephone=1 if has either telephone/mobiletelephone
// 43,385 1's, 4 missing
*/

replace telephone = mobiletelephone


	//Label indicators
lab var television "Household has television"
lab var radio "Household has radio"	
lab var telephone "Household has telephone (mobilephone)"	
lab var refrigerator "Household has refrigerator"
lab var car "Household has car"
lab var bicycle "Household has bicycle"	
lab var motorbike "Household has motorbike"
lab var computer "Household has computer"
lab var animal_cart "Household has animal cart"

		
*** Standard MPI ***
/* Members of the household are considered deprived in assets if the household 
does not own more than one of: radio, TV, telephone, refrigerator, bike, motorbike, 
refrigerator, computer or animal cart and does not own a car or truck.*/
*****************************************************************************

egen n_small_assets2 =rowtotal(television radio telephone refrigerator bicycle motorbike computer animal_cart), missing
lab var n_small_assets2 "Household Number of Small Assets Owned" 

gen hh_assets2 = (car==1 | n_small_assets2 > 1) 
replace hh_assets2 = . if car==. & n_small_assets2==.
lab var hh_assets2 "Household Asset Ownership: HH has car or more than 1 small assets incl computer & animal cart"
tab hh_assets2, m  // 8.73% deprived

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
clonevar windex=hv270  // wealth index combined

desc hv271
clonevar windexf=hv271  // wealth index factor score combined (5 decimals) 


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
 
save "$path_out/khm_dhs21-22_raw.dta", replace 

*** Rename key global MPI indicators for estimation ***
recode hh_mortality_u18_5y  (0=1)(1=0) , gen(d_cm)
recode hh_nutrition_uw_st 	(0=1)(1=0) , gen(d_nutr)
recode hh_child_atten 		(0=1)(1=0) , gen(d_satt)
recode hh_years_edu6 		(0=1)(1=0) , gen(d_educ)
recode electricity 			(0=1)(1=0) , gen(d_elct)
recode water_mdg 			(0=1)(1=0) , gen(d_wtr)
recode toilet_mdg 			(0=1)(1=0) , gen(d_sani)
recode housing_no_wall 		(0=1)(1=0) , gen(d_hsg)  // housing_1 in standard MPI
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
// Harmonization: headship not kept as it is not computed in 2021-22

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
char _dta[year] "2021-2022" 	
char _dta[survey] "DHS"
char _dta[ccnum] "116"
char _dta[type] "micro"


*** Sort, compress and save data for estimation ***
sort ind_id
compress
la da "Micro data for `_dta[ccty]' (`_dta[ccnum]') from `c(current_date)' (`c(current_time)')."
save "$path_out/khm_dhs21-22.dta", replace 

