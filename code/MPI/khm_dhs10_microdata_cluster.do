clear all 

cd "C:\Users\tianc\OneDrive\Documents\SIG\DISES\code\MPI"
// Working Folder Path
global path_data "../../data/MPI/khm_dhs10"

use "$path_data/khm_dhs10.dta", clear

gen clust_no = floor(ind_id/1000000)

codebook clust_no

label var clust_no "Cluster number"

save "$path_data/khm_dhs10_clustno.dta" 
