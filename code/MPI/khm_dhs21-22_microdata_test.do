********************************************************************************
/* Adapted from:
Oxford Poverty and Human Development Initiative (OPHI), University of Oxford. 
2023 Global Multidimensional Poverty Index - Cambodia DHS 2021-2022
[STATA do-file]. Available from http://ophi.org.uk/  

For further queries, contact: ophi@qeh.ox.ac.uk */
********************************************************************************

clear all 
set more off
set maxvar 10000


global path_in "../rdta/Cambodia DHS 2021-22"   		// folder path
global path_out "cdta"
global path_ado "ado"


********************************************************************************
**# Step 1: Data preparation 
********************************************************************************

	
********************************************************************************
**# Step 1.1 CHILDREN UNDER 5
********************************************************************************

use "$path_in/KHPR81FL.dta", clear 

gen double ind_id = hv001*1000000 + hv002*100 + hvidx 
format ind_id %20.0g
duplicates report ind_id


tab hv120, m            // qc: 4,499 children eligible for measurement	
count if hc1!=.        // qc: children have data on age in months
ta hv105 if hc1!=.    // qc: all are within the 5 year age group
keep if hv120==1

gen child_id=1
lab var child_id "child under 5" 
count


desc hc27 hv104 			  // sex
compare hc27 hv104			 // qc: hc27 matches hv104
codebook hc27				// 1=male; 2=female 
clonevar gender = hc27



desc hc1 hc1a 					// qc: use age in days if available 
clonevar age_days = hc1a
su age_days 					// qc: check min & max value
	
gen str6 ageunit = "days"
lab var ageunit "days"



codebook hc2, ta (999)  			   // qc: body weight in kilogram (kg)
gen	weight = hc2/10 if hc2<9990 	   // qc: check out of range value 
ta hc13 hc2 if hc2>=9990, m 		   // qc: why missing	
su weight


codebook hc3, ta (999) 				// qc: height in centimeters (cm)
gen	height = hc3/10 if hc3<9990     // qc: check out of range value   
ta hc13 hc3 if hc3>=9990, m			// qc: why missing	
su height


codebook hc15 								 // how child was measured
gen measure = "l" if hc15==1 				 // lying down
replace measure = "h" if hc15==2 			 // standing up
replace measure = " " if hc15==0 | hc15==.   // " " if unknown
ta measure


gen  oedema = "n" 							// oedema


gen sw = 1									// sampling weight

gen weight_ch = hv005/1000000
lab var weight_ch "sample weight child under 5" 


adopath + "$path_ado/igrowup_stata"		 	 //compute z-score
gen str100 reflib = "$path_ado/igrowup_stata"
lab var reflib "Directory of reference tables"
gen str100 datalib = "$path_out" 
lab var datalib "Directory for datafiles"
gen str30 datalab = "children_nutri_khm" 
lab var datalab "Working file"


igrowup_restricted reflib datalib datalab gender age_days ///
ageunit weight height measure oedema sw


use "$path_out/children_nutri_khm_z_rc.dta", clear 

	
gen	underweight = (_zwei < -2.0) 
replace underweight = . if _zwei == . | _fwei==1
lab var underweight  "child is underweight"
ta underweight [aw=weight_ch],m 			// qc: matches report (p.234) 	 


gen stunting = (_zlen < -2.0)
replace stunting = . if _zlen == . | _flen==1
lab var stunting "child is stunted"
ta stunting [aw=weight_ch],m				// qc: matches report (p.234) 


gen wasting = (_zwfl < - 2.0)
replace wasting = . if _zwfl == . | _fwfl == 1
lab var wasting  "child is wasted"
ta wasting [aw=weight_ch]


gen	underweight_u = (_zwei < -3.0) 
replace underweight_u = . if _zwei == . | _fwei==1
lab var underweight_u  "child is severely underweight"


gen stunting_u = (_zlen < -3.0)
replace stunting_u = . if _zlen == . | _flen==1
lab var stunting_u "child is severely stunted"


gen wasting_u = (_zwfl < - 3.0)
replace wasting_u = . if _zwfl == . | _fwfl == 1
lab var wasting_u  "child is severely wasted"


count if _fwei==1 | _flen==1  	// z-scores which are biologically implausible
  

keep ind_id child_id weight_ch underweight* stunting* wasting* 
order ind_id child_id weight_ch underweight* stunting* wasting*
sort ind_id
save "$path_out/KHM21-22_CH.dta", replace



erase "$path_out/children_nutri_khm_z_rc.xls" 				// erase files
erase "$path_out/children_nutri_khm_prev_rc.xls"
erase "$path_out/children_nutri_khm_z_rc.dta"


********************************************************************************
**# Step 1.2  BIRTH HISTORY
********************************************************************************

use "$path_in/KHBR81FL.dta", clear

gen double ind_id = v001*1000000 + v002*100 + v003 
format ind_id %20.0g

gen fem_bh = 1
lab var fem_bh "female with birth history" 


desc b3 b7	
gen date_death = b3 + b7			 //  (date of birth) + (age at death)	
gen mdead_svy = v008 - date_death 	//	(date of interview) - (date of death)


gen ydead_svy = mdead_svy/12
lab var ydead_svy "total years dead from svy year"	
su ydead_svy


gen age_death = b7	
lab var age_death "age at death (months)"	
ta age_death, m


codebook b5, tab (10)	
gen child_died = 1 if b5==0
replace child_died = 0 if b5==1
replace child_died = . if b5==.
lab def lab_died 0"alive" 1"died"
lab val child_died lab_died
lab var child_died "child alive/dead"
ta b5 child_died, m


bys ind_id: egen tot_child_died = sum(child_died)  
 // number of children who died for each women

 
egen tot_child_died_2 = rsum(v206 v207) // v206-7: sons/daughters who have died
compare tot_child_died tot_child_died_2   // qc: figures are identical



gen child18_died = child_died  // child under 18 mortality in the last 5 years
replace child18_died=0 if age_death>=216 & age_death!=.
lab def lab_u18died 1 "child u18 has died" 0 "child is alive/died but older"
lab val child18_died lab_u18died
ta child18_died, m	

bys ind_id: egen tot_child18_died_5y=sum(child18_died) if ydead_svy<=5

replace tot_child18_died_5y=0 if tot_child18_died_5y==. & ///
								 tot_child_died>=0 & tot_child_died!=.
/* note: all children who are alive or who died longer than 
5 years from the interview date are replaced as '0' */

	
replace tot_child18_died_5y=. if child18_died==1 & ydead_svy==.
// note: replaced as '.' if there is no data on when the child died  

ta tot_child_died tot_child18_died_5y, m

bys ind_id: egen childu18_died_per_wom_5y = max(tot_child18_died_5y)
lab var childu18_died_per_wom_5y "total under 18 death in the last 5 years"	



bys ind_id: gen id=1 if _n==1
keep if id==1								// keep one observation per women
drop id
duplicates report ind_id 


	
keep ind_id fem_bh childu18_died_per_wom_5y		// keep relevant variables
order ind_id fem_bh childu18_died_per_wom_5y
sort ind_id
save "$path_out/KHM21-22_BH.dta", replace	


********************************************************************************
**# Step 1.3  INDIVIDUAL (WOMEN) 
********************************************************************************

use "$path_in/KHIR81FL.dta", clear


gen double ind_id = v001*1000000 + v002*100 + v003 
format ind_id %20.0g
duplicates report ind_id


gen wom_id = 1 
lab var wom_id "female 15-49 recode" 


ta v012, m 						  // qc: age 15-49 years, match svy report (p.6)

codebook v201 v206 v207,tab (999)  // qc: check for missing values


keep ind_id wom_id v005 v012 v201 v206 v207 
order ind_id wom_id v005 v012 v201 v206 v207 
sort ind_id
save "$path_out/KHM21-22_WM.dta", replace


********************************************************************************
**# Step 1.4  BMI-FOR-AGE (GIRLS 15-19)
********************************************************************************

use "$path_in/KHPR81FL.dta", clear 

gen double ind_id = hv001*1000000 + hv002*100 + hvidx 
format ind_id %20.0g


ta ha13,m
ta ha13 if hv105>=15 & hv105<=49 & hv104==2,m 			  // qc: if sample
ta ha13 if hv105>=15 & hv105<=49 & hv104==2 & hv027==0,m  // qc: if subsample

ta ha13 if hv105>=15 & hv105<=19 & hv104==2 & hv027==0,m  // qc: 15-19 years	
keep if hv105>=15 & hv105<=19 & hv104==2 & hv027==0


gen girl_id=1 
lab var girl_id "girls 15-19 selected for measurement" 
count
	
	
gen gender = 2						//2:female	


lookfor hv807c hv008 ha32 			//age 
gen age_month = hv807c - ha32
lab var age_month "age in months, girls 15-19 years"	
su age_month
count if age_month <= 228

gen str6 ageunit = "months" 
lab var ageunit "months"

		
codebook ha2, ta (999)   				// qc: body weight in kilogram (kg)
gen weight = ha2/10 if ha2<9990	
ta ha13 if ha2>9990, m
su weight


codebook ha3, ta (999) 				 // qc: height in centimeters (cm)
gen height = ha3/10 if ha3<9990
ta ha13 if ha3>9990, m
su height


gen oedema = "n"  							// oedema
	
	
gen sw = 1									// sampling weight


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
lab var z_bmi "z-score bmi-for-age"


gen	low_bmiage = (z_bmi < -2.0) 					// mpi
replace low_bmiage = . if z_bmi==.
lab var low_bmiage "low bmi-for-age"


gen	low_bmiage_u = (z_bmi < -3.0) 					// destitution
replace low_bmiage_u = . if z_bmi==.
lab var low_bmiage_u "dst: low bmi-for-age"

ta low_bmiage, m
ta low_bmiage_u, m


	
keep ind_id girl_id age_month low_bmiage*
order ind_id girl_id age_month low_bmiage*
sort ind_id
save "$path_out/KHM21-22_girls.dta", replace



erase "$path_out/girl_nutri_khm_z.xls"  			// erase files
erase "$path_out/girl_nutri_khm_prev.xls"
erase "$path_out/girl_nutri_khm_z.dta"


********************************************************************************
**# Step 1.5  INDIVIDUAL (MEN)  
********************************************************************************

use "$path_in/KHMR81FL.dta", clear 

	
gen double ind_id = mv001*1000000 + mv002*100 + mv003 	
format ind_id %20.0g
duplicates report ind_id


gen men_id = 1 	
lab var men_id "man 15-49 recode" 


ta mv012, m 						   // qc: age 15-59 years


codebook mv201 mv206 mv207,tab (999)  // qc: check for missing values

	
keep ind_id men_id mv003 mv005 mv012 mv201 mv206 mv207 
order ind_id men_id mv003 mv005 mv012 mv201 mv206 mv207 
sort ind_id
save "$path_out/KHM21-22_MN.dta", replace


********************************************************************************
**# Step 1.6  BMI-FOR-AGE (BOYS 15-19)
********************************************************************************

	// anthropometric data not collected for male.
	
		
********************************************************************************
**# Step 1.7  HOUSEHOLD MEMBERS 
********************************************************************************

use "$path_in/KHPR81FL.dta", clear 


gen double hh_id = hv001*10000 + hv002 
format hh_id %20.0g
lab var hh_id "household id"


gen double ind_id = hv001*1000000 + hv002*100 + hvidx 
format ind_id %20.0g
lab var ind_id "individual id"

duplicates report ind_id 


sort hh_id ind_id


bys hh_id: gen id = _n
count if id==1					// 20,806 hh - matches report, p.6.


********************************************************************************
**# Step 1.8 DATA MERGING 
********************************************************************************
 
 
merge 1:1 ind_id using "$path_out/KHM21-22_BH.dta"  			 // bh recode
drop _merge
erase "$path_out/KHM21-22_BH.dta"


merge 1:1 ind_id using "$path_out/KHM21-22_WM.dta" 				 // wom recode
drop _merge
erase "$path_out/KHM21-22_WM.dta"

	

merge 1:1 ind_id using "$path_out/KHM21-22_girls.dta"			// girls 15-19
drop _merge
erase "$path_out/KHM21-22_girls.dta"	
	
	

merge 1:1 ind_id using "$path_out/KHM21-22_MN.dta" 				 // mn recode
drop _merge
erase "$path_out/KHM21-22_MN.dta"	



merge 1:1 ind_id using "$path_out/KHM21-22_CH.dta"  			// ch recode
drop _merge
erase "$path_out/KHM21-22_CH.dta"


sort ind_id


********************************************************************************
**# Step 1.9 USUAL HOUSEHOLD MEMBERS ***
********************************************************************************

codebook hv102, ta (9) 
drop if hv102!=1 


********************************************************************************
**# Step 1.10 ANTHROPOMETRIC SUBSAMPLE ***
********************************************************************************


/* note: height and weight measurements was collected from 
children under five and women 15-49 years living in 50% of 
the households that was not selected for male interview. */


codebook hv027
ta ha13 hv027,m
ta child_id hv027,m

drop if hv027!=0

	
********************************************************************************
**# Step 1.11 CONTROL VARIABLES
********************************************************************************


ta ha13, m										// eligible women for nutr
ta ha13 if hv105>=15 & hv105<=49 & hv104==2, m

gen fem_nutri_eligible = (ha13!=.)
ta fem_nutri_eligible, m
bys hh_id: egen hh_n_fem_nutri_eligible = sum(fem_nutri_eligible) 	
gen	no_fem_nutri_eligible = (hh_n_fem_nutri_eligible==0)
lab var no_fem_nutri_eligible "hh has no elig woman for nutr"	
drop hh_n_fem_nutri_eligible
ta no_fem_nutri_eligible, m


gen	child_eligible = (hv120==1) 				// eligible child for nutr
bys	hh_id: egen hh_n_children_eligible = sum(child_eligible) 
gen	no_child_eligible = (hh_n_children_eligible==0) 
lab var no_child_eligible "hh has no elig child for anthro"
drop hh_n_children_eligible
ta no_child_eligible, m


gen no_adults_eligible = (no_fem_nutri_eligible==1)  
lab var no_adults_eligible "hh has no elig adult for nutr"
ta no_adults_eligible, m 


gen no_eligibles = (no_fem_nutri_eligible==1 & no_child_eligible==1)
lab var no_eligibles "hh has no elig member for nutr"
ta no_eligibles, m




gen	fem_eligible = (hv117==1)  					// eligible women for cm
bys	hh_id: egen hh_n_fem_eligible = sum(fem_eligible) 	
gen	no_fem_eligible = (hh_n_fem_eligible==0) 									
lab var no_fem_eligible "hh has no elig woman"
drop hh_n_fem_eligible 
ta no_fem_eligible, m



sort hh_id ind_id


********************************************************************************
**# 1.12 RELEVANT VARIABLES ***
********************************************************************************

desc hv005 hv021 hv022

gen weight = hv005/1000000 							      // sample weight 
lab var weight "sample weight"


clonevar psu = hv021									// sample design
lab var psu "primary sampling unit"


clonevar strata = hv022
lab var strata "sample strata"

svyset psu [pw=weight] , strata(strata)	 singleunit(centered)



codebook hv025											// area: urban-rural	
recode hv025 (1=1 "urban") (2=0 "rural"), gen (area)			
lab var area "area: urban-rural"
ta hv025 area, m

	
	
codebook hv101, ta (99)										   // relationship
recode hv101 (1=1 "head")(2=2 "spouse")(3 11=3 "child") ///
(4/10=4 "extended family")(12/15=5 "not related")(98=.), ///
gen (relationship)
lab var relationship "relationship to the head of hh"
ta hv101 relationship, m	



codebook hv104													// sex
clonevar sex = hv104  
lab var sex "sex of household member"



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



codebook hv105, ta (999)							// age; age group
clonevar age = hv105  
replace age = . if age>=98
lab var age "age of household member"


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
lab var marital "marital status of household member"
ta hv115 marital, m


gen member = 1 										// hh size
bys hh_id: egen hhsize = sum(member)
lab var hhsize "household size"
ta hhsize, m


		
codebook hv024, ta (99)								// subnational regions


gen region = hv024
lab var region "subnational region"
  	
lab def la_reg ///
1 "Banteay Meanchay" 2 "Battambang" 3 "Kampong Cham" 4 "Kampong Chhnang" ///
5 "Kampong Speu" 6 "Kampong Thom" 7 "Kampot" 8 "Kandal" 9 "Koh Kong" ///
10 "Kratie" 11 "Mondul Kiri" 12 "Phnom Penh" 13 "Preah Vihear"  ///
14 "Prey Veng" 15 "Pursat" 16 "Ratanak Kiri" 17 "Siem Reap" ///
18 "Preah Sihanouk" 19 "Stung Treng" 20 "Svay Rieng" ///
21 "Takeo" 22 "Otdar Meanchey" 23 "Kep"  24 "Pailin" 25 "Tboung Khmum" 
lab val region la_reg


									// subnational region, harmonised over time

recode hv024 (1=1 "Banteay Meanchay") (3 25=2 "Kampong Cham")  ///
(4=3 "Kampong Chhnang") (5=4 "Kampong Speu") (6=5 "Kampong Thom")  ///
(8=6 "Kandal") (10=7 "Kratie") (12=8 "Phnom Penh") (14=9 "Prey Veng") ///
(15=10 "Pursat")(17=11 "Siem Reap")(20=12 "Svay Rieng")(21=13 "Takeo") ///
(22=14 "Otdar Meanchey")(2 24 = 15 "Battambang & Pailin")(7 23=16 "Kampot & Kep") ///
(9 18=17 "Preah Sihanouk and Koh Kong") (13 19 =18 "Preah Vihear and Stung Treng") ///
(11 16= 19 "Mondul Kiri and Ratanak Kiri"), gen(region_01)

lab var region_01 "hot: subnational region"
codebook region_01, ta(99)



********************************************************************************
**#  Step 2 Data preparation  ***
***  Standardization of the global MPI indicators   
********************************************************************************

********************************************************************************
**# Step 2.1 Years of Schooling ***
********************************************************************************

codebook hv108 hv106, ta(99)
ta hv108 hv106,m

clonevar  eduyears = hv108 if hv108 < 98              // years of educ
replace eduyears = 6  if hv108==98 & hv106==2      	 // check missing   
replace eduyears = 12 if hv108==98 & hv106==3 

replace eduyears = . if age<=eduyears & age>0 
	// note: years of schooling is greater than age
	
replace eduyears = 0 if age<10  		
replace eduyears = 0 if (age==10 | age==11) & eduyears < 6 
			// non-eligible age group		
lab var eduyears "total years of educ"
ta eduyears, m


gen educ_elig = 1  							// eligibility for educ indicator 
replace educ_elig = 0 if age < 10  
replace educ_elig = 0 if (age==10 | age==11) & eduyears < 6 
lab def lab_educ_elig 0"not eligible" 1"eligible"  
lab val educ_elig lab_educ_elig
lab var educ_elig "eligibility for educ indicator"
ta eduyears educ_elig,m


	/* control variable: information on years of educ 
	present for at least 2/3 of the eligible householders */		
gen temp = 1 if eduyears!=. & educ_elig == 1
bys	hh_id: egen no_mis_edu = sum(temp)		// elig with educ data 
	
bys hh_id: egen hhs = sum(educ_elig == 1) 		// all eligible for educ

replace no_mis_edu = no_mis_edu/hhs
replace no_mis_edu = (no_mis_edu>=2/3)		
ta no_mis_edu, m							// qc: missing (0) is < 0.5% 
lab var no_mis_edu "no missing yos"
drop temp hhs


*** MPI ***
/* Householders are considered not deprived if at least 
one eligible householder has six or more years of education. */
******************************************************************* 
gen	educ6 = (eduyears>=6 & eduyears!=.)
replace educ6 = . if eduyears==.

bys hh_id: egen educ = max(educ6)
replace educ = . if educ==0 & no_mis_edu==0
lab var educ "non-deprivation in education"
ta educ, m 

	
*** Destitution ***
/* Householders are considered not deprived if at least 
one eligible householder has one or more years of education. */
******************************************************************* 
gen	educ1 = (eduyears>=1 & eduyears!=.)
replace educ1 = . if eduyears==.

bys	hh_id: egen educ_u = max(educ1)
replace educ_u = . if educ_u==0 & no_mis_edu==0
lab var educ_u "dst: non-deprivation in education"
ta educ_u,m



********************************************************************************
**# Step 2.2 School Attendance ***
********************************************************************************

codebook hv121, ta (99)
recode hv121 (2=1 "attending") (0=0 "not attending"), gen (attendance)
lab var attendance "current school year"	
ta attendance, m


*** MPI ***
/* Householders are considered not deprived if all 
school-aged children are attending up to class 8. */ 
******************************************************************* 
gen	child_schoolage = (age>=6 & age<=14)
lab var child_schoolage "eligible for school attendance"		
	// qc: official school entrance age to primary school: 6 years
	// qc: age range 6-14 (=6+8) 
	

	/* control variable: school attendance data is 
	missing for at least 2/3 of the school-aged children */
count if child_schoolage==1 & attendance==.			// qc: missing satt
gen temp = 1 if child_schoolage==1 & attendance!=. 	// elig children in school 
bys hh_id: egen no_missing_atten = sum(temp)		
gen temp2 = 1 if child_schoolage==1					//elig children
bys hh_id: egen hhs = sum(temp2)					
replace no_missing_atten = no_missing_atten/hhs 
replace no_missing_atten = (no_missing_atten>=2/3)	 		
ta no_missing_atten, m							     // qc: missing < 0.5% 
lab var no_missing_atten "no missing satt"		
drop temp temp2 hhs


bys hh_id: egen hh_children_schoolage = sum(child_schoolage)
replace hh_children_schoolage = (hh_children_schoolage>0) 
lab var hh_children_schoolage "hh has elig child"

gen	not_atten = (attendance==0) if child_schoolage==1
replace not_atten = . if attendance==. & child_schoolage==1

bysort	hh_id: egen any_not_atten = max(not_atten)

gen	satt = (any_not_atten==0) 
replace satt = . if any_not_atten==.
replace satt = 1 if hh_children_schoolage==0
replace satt = . if satt==1 & no_missing_atten==0 
lab var satt "non-deprivation in school attendance"
ta satt, m

	
*** Destitution ***
/* Householders are considered not deprived if all 
school-aged children are attending up to class 6. */ 
******************************************************************* 
gen	child_schoolage_u = (age>=6 & age<=12) 
lab var child_schoolage_u "dst: eligible for school attendance"	


	/* control variable: school attendance data is 
	missing for at least 2/3 of the school-aged children */	
count if child_schoolage_u==1 & attendance==.	
gen temp = 1 if child_schoolage_u==1 & attendance!=.
bys hh_id: egen no_missing_atten_u = sum(temp)	
gen temp2 = 1 if child_schoolage_u==1	
bys hh_id: egen hhs = sum(temp2)
replace no_missing_atten_u = no_missing_atten_u/hhs 
replace no_missing_atten_u = (no_missing_atten_u>=2/3)			
ta no_missing_atten_u, m			// qc: missing (0) is < 0.5% 
lab var no_missing_atten_u "no missing satt"		
drop temp temp2 hhs


bys	hh_id: egen hh_children_schoolage_u = sum(child_schoolage_u)
replace hh_children_schoolage_u = (hh_children_schoolage_u>0) 
lab var hh_children_schoolage_u "hh has elig child"

gen	atten_6 = (attendance==1) if child_schoolage_u==1
replace atten_6 = . if attendance==. & child_schoolage_u==1

bys	hh_id: egen any_atten_6 = max(atten_6)

gen	satt_u = (any_atten_6==1) 
replace satt_u = . if any_atten_6==.
replace satt_u = 1 if hh_children_schoolage_u==0
replace satt_u = . if satt_u==0 & no_missing_atten_u==0 
lab var satt_u "dst: non-deprivation in school attendance"
ta satt_u, m


********************************************************************************
**# Step 2.3 Nutrition 
********************************************************************************

********************************************************************************
**# Step 2.3a bmi & bmi-for-age ***
********************************************************************************

foreach var in ha40 {
			 gen inf_`var' = 1 if `var'!=.
			 bys sex: ta age inf_`var' 
			  // qc: women 15-49 years measured
			 drop inf_`var'
}

gen	f_bmi = ha40/100  							 			// bmi - woman
lab var f_bmi "women's bmi"
gen	f_low_bmi = (f_bmi<18.5)
replace f_low_bmi = . if f_bmi==. | f_bmi>=99.97
lab var f_low_bmi "bmi of women < 18.5"


gen	f_low_bmi_u = (f_bmi<17)
replace f_low_bmi_u = . if f_bmi==. | f_bmi>=99.97
lab var f_low_bmi_u "bmi of women <17"



gen low_bmi_byage = 0 							// MPI: bmi-for-age and bmi
lab var low_bmi_byage "low bmi or bmi-for-age"
replace low_bmi_byage = 1 if f_low_bmi==1		           //low bmi, woman		
replace low_bmi_byage = 1 if low_bmiage==1 & age_month!=.  //bmi-for-age, girls
replace low_bmi_byage = 0 if low_bmiage==0 & age_month!=. 			
replace low_bmi_byage = . if f_low_bmi==. & low_bmiage==. 		// missing
		
bys hh_id: egen low_bmi = max(low_bmi_byage)		

gen	hh_no_low_bmiage = (low_bmi==0) 			// 1=normal bmi or bmi-for-age 
replace hh_no_low_bmiage = . if low_bmi==.		//non-eligible, missing
replace hh_no_low_bmiage = 1 if no_adults_eligible==1	//no eligible adult
drop low_bmi
lab var hh_no_low_bmiage "no adult with low bmi or bmi-for-age"
ta hh_no_low_bmiage, m	



gen low_bmi_byage_u = 0				// dst: bmi-for-age and bmi
lab var low_bmi_byage_u "dst: low bmi or bmi-for-age"
replace low_bmi_byage_u = 1 if f_low_bmi_u==1 
replace low_bmi_byage_u = 1 if low_bmiage_u==1 & age_month!=.
replace low_bmi_byage_u = 0 if low_bmiage_u==0 & age_month!=.		
replace low_bmi_byage_u = . if f_low_bmi_u==. & low_bmiage_u==. 	// missing

bys hh_id: egen low_bmi = max(low_bmi_byage_u)

gen	hh_no_low_bmiage_u = (low_bmi==0)
replace hh_no_low_bmiage_u = . if low_bmi==.
replace hh_no_low_bmiage_u = 1 if no_adults_eligible==1	
drop low_bmi
lab var hh_no_low_bmiage_u "dst: no adult with low bmi or bmi-for-age"
ta hh_no_low_bmiage_u, m	


********************************************************************************
**# Step 2.3b underweight, stunting & wasting
********************************************************************************

bys hh_id: egen temp = max(underweight)
gen	hh_no_underweight = (temp==0)		// no child is underweight 
replace hh_no_underweight = . if temp==.
replace hh_no_underweight = 1 if no_child_eligible==1	
lab var hh_no_underweight "hh has no child underweight"
drop temp

bys hh_id: egen temp = max(underweight_u) 			
gen	hh_no_underweight_u = (temp==0) 	// no child is severely underweight 
replace hh_no_underweight_u = . if temp==.
replace hh_no_underweight_u = 1 if no_child_eligible==1 
lab var hh_no_underweight_u "dst: hh has no child underweight"
drop temp



bys hh_id: egen temp = max(stunting)
gen	hh_no_stunting = (temp==0)					// no child is stunted 
replace hh_no_stunting = . if temp==.
replace hh_no_stunting = 1 if no_child_eligible==1	
lab var hh_no_stunting "hh has no child stunted"
drop temp

bys hh_id: egen temp = max(stunting_u) 				
gen	hh_no_stunting_u = (temp==0) 				// no child is severely stunted 
replace hh_no_stunting_u = . if temp==.
replace hh_no_stunting_u = 1 if no_child_eligible==1 
lab var hh_no_stunting_u "dst: hh has no child stunted"
drop temp



bys hh_id: egen temp = max(wasting)
gen	hh_no_wasting = (temp==0) 						// no child is wasted
replace hh_no_wasting = . if temp==.
replace hh_no_wasting = 1 if no_child_eligible==1		
lab var hh_no_wasting "hh has no child wasted"
drop temp

bys hh_id: egen temp = max(wasting_u) 			
gen	hh_no_wasting_u = (temp==0) 				// no child is severely wasted
replace hh_no_wasting_u = . if temp==.
replace hh_no_wasting_u = 1 if no_child_eligible==1 
lab var hh_no_wasting_u "dst: hh has no child wasted"
drop temp



gen uw_st = 1 if stunting==1 | underweight==1		// underweight or stunted 
replace uw_st = 0 if stunting==0 & underweight==0
replace uw_st = . if stunting==. & underweight==.
lab var uw_st "child is underweight or stunted"

bys hh_id: egen temp = max(uw_st)
gen	hh_no_uw_st = (temp==0)		
replace hh_no_uw_st = . if temp==.
replace hh_no_uw_st = 1 if no_child_eligible==1	
lab var hh_no_uw_st "hh has no child underweight or stunted"
drop temp

gen uw_st_u = 1 if stunting_u==1 | underweight_u==1 
replace uw_st_u = 0 if stunting_u==0 & underweight_u==0
replace uw_st_u = . if stunting_u==. & underweight_u==.
lab var uw_st_u "dst: child is underweight or stunted"

bys hh_id: egen temp = max(uw_st_u)
gen	hh_no_uw_st_u = (temp==0) 
replace hh_no_uw_st_u = . if temp==.
replace hh_no_uw_st_u = 1 if no_child_eligible==1 
lab var hh_no_uw_st_u "dst: hh has no child underweight or stunted"
drop temp


********************************************************************************
**# Step 2.3c nutrition indicator
********************************************************************************

*** MPI ***
/* Householders are not deprived if all eligible 
person with anthropometric measurement in the household 
are nourished; or household has no eligible person. */
************************************************************************
gen	nutr_2 = 1
replace nutr_2 = 0 if hh_no_low_bmiage==0 | hh_no_uw_st==0
replace nutr_2 = . if hh_no_low_bmiage==. & hh_no_uw_st==. 	// missing

replace nutr_2 = . if hh_no_low_bmiage==. & ///
					hh_no_uw_st==1 & no_child_eligible==1
	// elig adult has missing data; no elig child 
	
replace nutr_2 = . if hh_no_uw_st==. & ///
					hh_no_low_bmiage==1 & no_adults_eligible==1
	// elig child has missing data; no elig adult 
	
replace nutr_2 = 1 if no_eligibles==1    // non-applicable population	
lab var nutr_2 "non-deprivation in nutr (under 5 & women)"
ta nutr_2, m



gen	nutr_0 = 1  									// child under 5
replace nutr_0 = 0 if hh_no_uw_st==0
replace nutr_0 = . if hh_no_uw_st==.
replace nutr_0 = 1 if no_child_eligible==1   		
lab var nutr_0 "non-deprivation in nutr (under 5)"
tab nutr_0, m


*** Destitution ***
/* Householders are not deprived if all eligible person with
anthropometric measurement in the household are not severely 
undernourished; or household has no eligible person. */
************************************************************************
gen	nutr_2_u = 1
replace nutr_2_u = 0 if hh_no_low_bmiage_u==0 | hh_no_uw_st_u==0

replace nutr_2_u = . if (hh_no_low_bmiage_u==. & hh_no_uw_st_u==.)  | ///
(hh_no_low_bmiage_u==. & hh_no_uw_st_u==1 & no_child_eligible==1) | ///
(hh_no_uw_st_u==. & hh_no_low_bmiage_u==1 & no_adults_eligible==1)

replace nutr_2_u = 1 if no_eligibles==1  	
lab var nutr_2_u "dst: non-deprivation in nutr (under 5 & women)"
ta nutr_2_u, m



gen	nutr_0_u = 1  										// child under 5
replace nutr_0_u = 0 if hh_no_uw_st_u==0
replace nutr_0_u = . if hh_no_uw_st_u==.
replace nutr_0_u = 1 if no_child_eligible==1   	
lab var nutr_0_u "dst: non-deprivation in nutr (under 5)"
tab nutr_0_u, m


********************************************************************************
*** Step 2.4 Child Mortality ***
********************************************************************************
	
codebook v206 v207 
	/* v206: number of sons who have died 
	   v207: number of daughters who have died */
	
egen temp_f = rowtotal(v206 v207), missing
replace temp_f = 0 if v201==0 					 		// never given birth
bys	hh_id: egen child_mortality_f = sum(temp_f), missing
lab var child_mortality_f "child mortality reported by women"
ta child_mortality_f, m
drop temp_f


egen child_mortality = rowmax(child_mortality_f)
replace child_mortality = 0 if child_mortality==. & no_fem_eligible==1 
lab var child_mortality "total child mortality in a hh"
ta child_mortality, m
	

*** MPI *** 
/* Householders are not deprived if all eligible women 
in the household reported zero mortality among children 
under 18 in the last 5 years from the survey year.*/
************************************************************************
ta childu18_died_per_wom_5y, m	

replace childu18_died_per_wom_5y = 0 if v201==0 
	// elig woman who never ever gave birth 
	
replace childu18_died_per_wom_5y = 0 if no_fem_eligible==1	
	// no elig woman
	
bys hh_id: egen childu18_mortality_5y = sum(childu18_died_per_wom_5y), missing
replace childu18_mortality_5y = 0 if childu18_mortality_5y==. & child_mortality==0
	// women has missing value and men reported no death 
lab var childu18_mortality_5y "total u18 child mortality last 5 years"
ta childu18_mortality_5y, m		
	
	
gen cm_0 = (childu18_mortality_5y==0)
replace cm_0 = . if childu18_mortality_5y==.
lab var cm_0 "non-deprivation in cm"
ta cm_0, m


*** Destitution *** 
*** (same as MPI) ***
************************************************************************
clonevar cm_0_u = cm	
lab var cm_0_u "dst: non-deprivation in cm"	


********************************************************************************
**# Step 2.5 Electricity 
********************************************************************************

*** MPI ***
/* Householders are considered not deprived 
if the household has electricity */
****************************************
codebook hv206, ta (9)

recode hv206 (0=0 "no") (1=1 "yes") (9=.), gen (elct)
lab var elct "non-deprivation in electricity"
ta elct hv206,m


svy: prop elct 				// qc: matches the report (p.15)

	
*** Destitution ***
*** (same as MPI) ***
****************************************
gen elct_u = elct
lab var elct_u "dst: non-deprivation in electricity"


********************************************************************************
**# Step 2.6 Sanitation ***
********************************************************************************


*** MPI ***
/* Householders are not deprived if the household has improved 
sanitation facilities that are not shared with other households. */
********************************************************************
desc hv205 hv225 

codebook hv205, ta(99) 	
	
recode hv205 (11/13 15/22 41 = 1 "yes") ///
(14 23 31 42/96 = 0 "no") (99=.), gen(sani)


codebook hv225

replace sani = 0 if hv225==1				
lab var sani "non-deprivation in sanitation"
ta hv205 sani, m

svy: prop sani 			// qc: matches the report (p.364)


*** Destitution ***
/* Householders are not deprived if the 
household has sanitation facilities. */
********************************************************************
recode hv205 (11/23 41/43 = 1 "yes") ///
(31 96 = 0 "no") (99=.), gen(sani_u)

lab var sani_u "dst: non-deprivation in sanitation"
ta hv205 sani_u, m


********************************************************************************
**# Step 2.7 Drinking Water 
********************************************************************************


*** MPI ***
/* Householders are not deprived if household have access to safe 
drinking water and is under 30 minutes walk from home, round trip.*/
********************************************************************
codebook hv201, ta(99)

recode hv201 (11/31 41 51/71 = 1 "yes") ///
(32 42 43 96 = 0 "no") (99=.), gen(dwtr_src)
lab var dwtr_src "improved main source of drinking water"
ta hv201 dwtr_src,m


svy: prop dwtr_src			// qc: matches the report (p.357)


codebook hv204, ta(99) 								// time to water
	
clonevar wtr = dwtr_src	
replace wtr = 0 if hv204 >=30 & hv204 <=900						 
lab var wtr "non-deprivation in drinking water"
ta dwtr_src wtr,m


	
*** Destitution ***
/* Householders are not deprived if household have access to safe 
drinking water and is 45 minutes walk or less from home, round trip.*/
********************************************************************
clonevar wtr_u = dwtr_src						   
replace wtr_u = 0 if hv204 >45 & hv204 <=900				  
lab var wtr_u "dst: non-deprivation in drinking water"
ta dwtr_src wtr_u,m 


********************************************************************************
**# Step 2.8 Housing ***
********************************************************************************

desc hv213 hv214 hv215

codebook hv213, ta (99)			// improved = rudimentary & finished floor 
recode hv213 (21/35 = 1 "yes") (11 12 96 = 0 "no") (99=.), gen(floor)
lab var floor "hh has improved floor"
ta hv213 floor,m


codebook hv214, ta (99)					// improved = finished walls 
recode hv214 (31/37 = 1 "yes") (11/26 96 = 0 "no") (99=.), gen(wall)
lab var wall "hh has improved wall"
ta hv214 wall,m


codebook hv215, ta (99)					// improved = finished roofing 
recode hv215 (31/36 = 1 "yes") (11/24 96 = 0 "no") (99=.), gen(roof)
lab var roof "hh has improved roof"
ta hv215 roof,m	


*** MPI ***
/* Householders are not deprived in housing if the roof, 
floor and walls are constructed from quality materials.*/
**************************************************************
gen hsg = 1
replace hsg = 0 if floor==0 | wall==0 | roof==0
replace hsg = . if floor==. & wall==. & roof==.
lab var hsg "non-deprivation in housing"
ta hsg, m


*** Destitution ***
/* Householders are not deprived in housing if at least two of the three 
components (roof/floor/walls) are constructed from quality materials. */
**************************************************************
gen hsg_u = 1

replace hsg_u = 0 if ///
(floor==0 & wall==0 & roof==1) | ///
(floor==0 & wall==1 & roof==0) | ///
(floor==1 & wall==0 & roof==0) | ///
(floor==0 & wall==0 & roof==0)

replace hsg_u = . if floor==. & wall==. & roof==.
lab var hsg_u "dst: non-deprivation in housing"
ta hsg_u, m


********************************************************************************
**# Step 2.9 Cooking Fuel 
********************************************************************************

	
*** MPI ***
/* Householders are considered not deprived if the 
household uses non-solid fuels for cooking. */
*****************************************************************
codebook hv226, ta (99)


recode hv226 (1/5 95 96 = 1 "yes") ///
(9/16 = 0 "no") (99=.), gen(ckfl)

ta hv222 if hv226==96,m  // other uses three stone stove

replace ckfl = 0 if hv226==96 & hv222==9

lab var ckfl "non-deprivation in cooking fuel"	
ta hv226 ckfl,m 

svy: prop ckfl 				// qc: match the report (p.16)	


*** Destitution  ***
*** (same as MPI) ***
****************************************	
clonevar ckfl_u = ckfl 
lab var ckfl_u "dst: non-deprivation in cooking fuel"	
	

********************************************************************************
**# Step 2.10 Assets ***
********************************************************************************

	// radio/walkman/stereo/kindle
lookfor radio walkman stereo stéréo
codebook hv207
clonevar radio = hv207
lab var radio "hh has radio"


	// television/lcd tv/plasma tv/color tv/black & white tv
lookfor tv television plasma lcd télé tele
codebook hv208
clonevar television = hv208 
lab var television "hh has television"



	// refrigerator/icebox/fridge
lookfor refrigerator réfrigérateur refri freezer
codebook hv209
clonevar refrigerator = hv209
lab var refrigerator "hh has refrigerator"



	// bicycle/cycle rickshaw
lookfor bicycle bicyclette bicicleta
codebook hv210
clonevar bicycle = hv210 
lab var bicycle "hh has bicycle"	



	// motorbike/motorized bike/autorickshaw
lookfor motorbike moto
codebook hv211	
clonevar motorbike = hv211
lab var motorbike "hh has motorbike"



	// car/van/lorry/truck
lookfor car van truck
codebook hv212	
clonevar car = hv212  
lab var car "hh has car"	



	// handphone/telephone/iphone/mobilephone/ipod
lookfor telephone téléphone mobilephone ipod telefone tele celular
codebook hv221 hv243a
gen telephone = (hv221==1 | hv243a==1)
lab var telephone "hh has telephone"			
ta hv221 hv243a if telephone==1


	// animal cart
lookfor brouette cart carro carreta
codebook hv243c
clonevar animal_cart = hv243c
lab var animal_cart "hh has animal cart"	


	// computer/laptop/tablet
lookfor computer ordinateur laptop ipad tablet 
codebook hv243e
clonevar computer = hv243e
lab var computer "hh has computer"



lab def lab_asst 0"no" 1"yes"
foreach var in television radio telephone refrigerator car ///
			   bicycle motorbike computer animal_cart {
lab val `var' lab_asst	
replace `var' = . if `var'==9 | `var'==99 | `var'==8 | `var'==98	   	
}

		
*** MPI ***
/* Householders are considered not deprived in assets 
if the household own more than one of the assets. */
*****************************************************************************
egen n_small_asst = rowtotal (television radio telephone refrigerator ///
bicycle motorbike computer animal_cart), m
lab var n_small_asst "small assets owned by hh" 
 
 
gen asst = (car==1 | n_small_asst > 1) 
replace asst = . if car==. & n_small_asst==.
lab var asst "non-deprivation in assets"


												// harmonised asset, exc. comp
egen n_small_asst_70 = rowtotal (television radio telephone ///
refrigerator bicycle motorbike animal_cart), m
lab var n_small_asst_70 "small assets owned by hh (x comp)" 
   
   
gen asst_70 = (car==1 | n_small_asst_70 > 1) 
replace asst_70 = . if car==. & n_small_asst_70==.
lab var asst_70 "non-deprivation in assets (x comp)"



*** Destitution ***
/* Householders are considered not deprived in assets 
if the household own at least one asset. */
*****************************************************************************	
gen	asst_u = (car==1 | n_small_asst>0)
replace asst_u = . if car==. & n_small_asst==.
lab var asst_u "dst: non-deprivation in assets"



gen	asst_70_u = (car==1 | n_small_asst_70>0)  
replace asst_70_u = . if car==. & n_small_asst_70==.
lab var asst_70_u "dst: non-deprivation in assets (x comp)"

	
********************************************************************************
**# Step 2.11 MPI indicators
********************************************************************************


desc hv007 hv006 hv008 						// interview dates
clonevar intvw_y = hv007 	
clonevar intvw_m = hv006 
clonevar intvw_d = hv008 


recode cm_0   	(0=1)(1=0) , gen(d_cm)					// for MPI est 
recode nutr_2 	(0=1)(1=0) , gen(d_nutr)
recode satt 	(0=1)(1=0) , gen(d_satt)
recode educ 	(0=1)(1=0) , gen(d_educ)
recode elct		(0=1)(1=0) , gen(d_elct)
recode wtr 		(0=1)(1=0) , gen(d_wtr)
recode sani		(0=1)(1=0) , gen(d_sani)
recode hsg 		(0=1)(1=0) , gen(d_hsg)
recode ckfl 	(0=1)(1=0) , gen(d_ckfl)
recode asst 	(0=1)(1=0) , gen(d_asst)


recode cm_0_u   (0=1)(1=0) , gen(dst_cm)				// for dst est
recode nutr_2_u (0=1)(1=0) , gen(dst_nutr)
recode satt_u 	(0=1)(1=0) , gen(dst_satt)
recode educ_u 	(0=1)(1=0) , gen(dst_educ)
recode elct_u 	(0=1)(1=0) , gen(dst_elct)
recode wtr_u  	(0=1)(1=0) , gen(dst_wtr)
recode sani_u 	(0=1)(1=0) , gen(dst_sani)
recode hsg_u  	(0=1)(1=0) , gen(dst_hsg)
recode ckfl_u 	(0=1)(1=0) , gen(dst_ckfl)
recode asst_u 	(0=1)(1=0) , gen(dst_asst) 


recode cm_0   		(0=1)(1=0) , gen(d_cm_01)	 		// for hot MPI est 
recode nutr_2 		(0=1)(1=0) , gen(d_nutr_01)
recode satt 		(0=1)(1=0) , gen(d_satt_01)
recode educ 		(0=1)(1=0) , gen(d_educ_01)
recode elct			(0=1)(1=0) , gen(d_elct_01)
recode wtr 			(0=1)(1=0) , gen(d_wtr_01)
recode sani			(0=1)(1=0) , gen(d_sani_01)
recode hsg 			(0=1)(1=0) , gen(d_hsg_01)
recode ckfl 		(0=1)(1=0) , gen(d_ckfl_01)
recode asst_70 		(0=1)(1=0) , gen(d_asst_01)
 

recode cm_0_u   	(0=1)(1=0) , gen(dst_cm_01)			// for hot dst est
recode nutr_2_u		(0=1)(1=0) , gen(dst_nutr_01)
recode satt_u 		(0=1)(1=0) , gen(dst_satt_01)
recode educ_u 		(0=1)(1=0) , gen(dst_educ_01)
recode elct_u 		(0=1)(1=0) , gen(dst_elct_01)
recode wtr_u  		(0=1)(1=0) , gen(dst_wtr_01)
recode sani_u 		(0=1)(1=0) , gen(dst_sani_01)
recode hsg_u  		(0=1)(1=0) , gen(dst_hsg_01)
recode ckfl_u 		(0=1)(1=0) , gen(dst_ckfl_01)
recode asst_70_u 	(0=1)(1=0) , gen(dst_asst_01) 



lab def lab_dp 1"yes" 0"no"
foreach var in d_* dst_* d_*_* dst_*_* {
lab val `var' lab_dp
}

foreach var in cm nutr satt educ elct wtr sani hsg ckfl asst {
lab var d_`var' "deprived in `var'"
lab var dst_`var' "deprived in `var' (dst)"
lab var d_`var'_01 "deprived in `var' (hot)"
lab var dst_`var'_01 "deprived in `var' (dst-hot)"
}


keep hh_id ind_id strata psu weight sex age area ///
agec7 agec4 agec2 region region_* headship d_* dst_* 

	 
order hh_id ind_id strata psu weight sex age area ///
agec7 agec4 agec2 region region_* headship d_* dst_* 


mdesc psu strata area age headship region region_* d_* dst_*



char _dta[cty] "Cambodia"
char _dta[ccty] "KHM"
char _dta[year] "2021-2022" 	
char _dta[survey] "DHS"
char _dta[ccnum] "116"
char _dta[type] "micro"



sort ind_id
compress
la da "Micro data for `_dta[ccty]' (`_dta[ccnum]') from `c(current_date)' (`c(current_time)')."
save "$path_out/khm_dhs21-22.dta", replace 

