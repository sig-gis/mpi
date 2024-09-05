clear all 

cd "C:\Users\tianc\OneDrive\Documents\SIG\DISES\code\MPI"
// Working Folder Path
global path_data "../../data/MPI/khm_dhs14_cot_nowall"

use "$path_data/khm_dhs14.dta", clear 

levelsof psu, local(clust_nos)
foreach clust_no in `clust_nos' {

display `clust_no'
use "$path_data/khm_dhs14.dta", clear 
keep if psu == `clust_no'


// adapted from Benin_dhs17-18.do	
********************************************************************************
*** List of the 10 indicators included in the MPI ***
********************************************************************************
gen edu_1 = d_educ
gen atten_1 = d_satt
gen cm_1 = d_cm
gen nutri_1 = d_nutr
gen elec_1 = d_elct
gen toilet_1 = d_sani
gen water_1 = d_wtr
gen house_1 = d_hsg  
gen fuel_1 = d_ckfl
gen asset_1 = d_asst

global est_1 edu_1 atten_1 cm_1 nutri_1 elec_1 toilet_1 water_1 house_1 fuel_1 asset_1
********************************************************************************
*** List of sample without missing values ***
********************************************************************************

foreach j of numlist 1 {
gen sample_`j' = (edu_`j'!=. & atten_`j'!=. & cm_`j'!=. & nutri_`j'!=. & elec_`j'!=. & toilet_`j'!=. & water_`j'!=. & house_`j'!=. & fuel_`j'!=. & asset_`j'!=.)


replace sample_`j' = . if subsample==0

sum sample_`j' [iw = weight]
gen per_sample_weighted_`j' = r(mean)

sum sample_`j'
gen per_sample_`j' = r(mean)
}

********************************************************************************
*** Define deprivation matrix 'g0' 
*** which takes values 1 if individual is deprived in the particular 
*** indicator according to deprivation cutoff z as defined during step 2 ***
********************************************************************************

foreach j of numlist 1 {
foreach var in ${est_`j'} {  
	gen g0`j'_`var' = `var'
	}
}
// same as edu_1 etc.	
	
*** Raw Headcount Ratios
foreach j of numlist 1 {
foreach var in ${est_`j'}   {  
	sum g0`j'_`var' if sample_`j'==1 [iw = weight]
	gen raw`j'_`var' = r(mean)*100
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
	
foreach var in edu_`j' atten_`j' {
capture drop w`j'_`var' 
	gen w`j'_`var' = 1/6
	}

foreach var in cm_`j' nutri_`j' {
	capture drop w`j'_`var'
	gen w`j'_`var' = 1/6
	}

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
	gen w`j'_g0_`var' = w`j'_`var' * g0`j'_`var' 
	replace w`j'_g0_`var' = . if sample_`j'!=1 
	}
}
********************************************************************************
*** Generate the vector of individual weighted deprivation count 'c'
********************************************************************************

foreach j of numlist 1 {
egen c_vector_`j' = rowtotal(w`j'_g0_*)
replace c_vector_`j' = . if sample_`j'!=1
}

********************************************************************************
*** Identification step according to poverty cutoff k (20 33.33 50) ***
********************************************************************************

foreach j of numlist 1 {
	foreach k of numlist 20 33 50 {
		gen multidimensionally_poor_`j'_`k' = (c_vector_`j'>=`k'/100)
		replace multidimensionally_poor_`j'_`k' = . if sample_`j'!=1 
	}
}

********************************************************************************
*** Generate the censored vector of individual weighted deprivation count 'c(k)'
********************************************************************************


foreach j of numlist 1 {
	foreach k of numlist 20 33 50 {
		gen c_censured_vector_`j'_`k' = c_vector_`j'
		replace c_censured_vector_`j'_`k' = 0 if multidimensionally_poor_`j'_`k'==0 
	}
}

********************************************************************************
*** Define censored deprivation matrix 'g0(k)' ***
********************************************************************************

foreach j of numlist 1 {
foreach var in ${est_`j'} {
	gen g0`j'_k_`var' = g0`j'_`var' 
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
		sum c_censured_vector_`j'_`k' [iw = weight] if sample_`j'==1
		gen MPI_`j'_`k' = r(mean)
		lab var MPI_`j'_`k' "MPI with k=`k'"
	}
	
	sum c_censured_vector_`j'_33 [iw = weight] if sample_`j'==1
	gen MPI_`j' = r(mean)
	lab var MPI_`j' "`j' Multidimensional Poverty Index (MPI = H*A): Range 0 to 1"
}

* Standard error
svyset hh_id
svy: mean c_censured_vector_1_33
matrix table = r(table)
gen MPI_1_svy = table[rownumb(table, "b"), 1]
gen MPI_1_SE = table[rownumb(table, "se"), 1]
gen MPI_1_low95CI = table[rownumb(table, "ll"), 1]
gen MPI_1_upp95CI = table[rownumb(table, "ul"), 1]


save "$path_data/khm_dhs14_mpi_clust`clust_no'.dta", replace
}
