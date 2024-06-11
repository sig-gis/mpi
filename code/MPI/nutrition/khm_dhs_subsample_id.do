********************************************************************************
*** Nutrition subsample indicator ***
********************************************************************************

clear all 
set more off

cd "C:\Users\tianc\OneDrive\Documents\SIG\DISES\code\MPI"
*** Working Folder Path ***
global path_in "../../data/DHS/Cambodia/STATA" 	  


*** Cambodia DHS 2000 ***

use "$path_in/KHPR42DT/KHPR42FL.DTA", clear 
lookfor collection
codebook shanthro

use "$path_in/KHHR42DT/KHHR42FL.DTA", clear 
lookfor collection
codebook shanthro
tab shanthro, freq  // 51.4% no, 48.6% yes


*** Cambodia DHS 2005 ***

use "$path_in/KHPR51DT/KHPR51FL.DTA", clear 
codebook hv042 shselhwt
compare hv042 shselhwt  // same

use hv042 shselhwt using "$path_in/KHHR51DT/KHHR51FL.DTA", clear 
codebook hv042 shselhwt
compare hv042 shselhwt  // same
tab hv042, freq  // 50.04% not selected, 49.96 selected


*** Cambodia DHS 2010 ***

use "$path_in/KHPR61DT/KHPR61FL.DTA", clear 
codebook hv027 hv042
compare hv027 hv042
tab hv042, freq

use "$path_in/KHHR61DT/KHHR61FL.DTA", clear 
codebook hv027 hv042
compare hv027 hv042
tab hv042, freq  // 50.06% not selected, 49.94 selected


*** Cambodia DHS 2014 ***

use "$path_in/KHPR73DT/KHPR73FL.DTA", clear 
codebook hv027 hv042
compare hv027 hv042  // same except for 0/1 vs 1/0
tab hv042, freq

use "$path_in/KHHR73DT/KHHR73FL.DTA", clear 
codebook hv027 hv042
compare hv027 hv042  // same except for 0/1 vs 1/0
tab hv042, freq  // 35.07% not selected, 64.93 selected
