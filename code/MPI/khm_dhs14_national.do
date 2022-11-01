clear all 

cd "C:\Users\tianc\OneDrive\Documents\SIG\DISES\code\MPI"
// Working Folder Path
global path_data "../../data/MPI/dta"

use "$path_data/khm_dhs14.dta", clear 

/*
svyset psu [pw=weight], strata(strata)

mpitb set, name(22103101)  ///
	d1(d_cm d_nutr, name(hl))  ///
	d2(d_satt d_educ, name(ed))  ///
	d3(d_elct d_wtr d_sani d_hsg d_ckfl d_asst, name(ls))
*/
	
svyset psu [pw=weight], strata(strata)

// equal weights among and within domains
mpi d1(d_cm d_nutr)  ///
	d2(d_satt d_educ)  ///
	d3(d_elct d_wtr d_sani d_hsg d_ckfl d_asst),  ///
	cutoff(0.3333)

mpi d1(d_cm d_nutr)  ///
	d2(d_satt d_educ)  ///
	d3(d_elct d_wtr d_sani d_hsg d_ckfl d_asst),  ///
	cutoff(0.3333)  ///
	by(region)
