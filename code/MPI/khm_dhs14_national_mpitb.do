clear all 

cd "C:\Users\tianc\OneDrive\Documents\SIG\DISES\code\MPI"
// Working Folder Path
global path_data "../../data/MPI/dta"

use "$path_data/khm_dhs14.dta", clear 


svyset psu [pw=weight], strata(strata)

mpitb set, name(r22112801)  ///
	d1(d_cm d_nutr, name(hl))  ///
	d2(d_satt d_educ, name(ed))  ///
	d3(d_elct d_wtr d_sani d_hsg d_ckfl d_asst, name(ls))

mpitb est, name(r22112801) weights(equal) meas(M0) klist(33)  ///
    svy lfr(myresults, replace)
	
cwf myresults

d

li measure b se