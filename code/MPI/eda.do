cd "C:\Users\tianc\OneDrive\Documents\SIG\DISES\code\MPI"


*** eda while going through khm_dhs14_microdata_test.do ***

*** Working Folder Path ***
global path_in "../../data/DHS/Cambodia/STATA" 	  
global path_out "../../data/MPI/khm_dhs14"
global path_ado "ado"

*** Step 1.8 ***
use "$path_out/KHM14_BR.dta"
use "$path_out/KHM14_IR.dta"
use "$path_out/KHM14_PR_girls.dta"
use "$path_out/KHM14_PR_child.dta"
// some ind_id missing so when merging,
// error: variable ind_id does not uniquely identify observations in the using data

