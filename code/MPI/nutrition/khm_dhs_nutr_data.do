********************************************************************************
*** Nutrition-related data ***
********************************************************************************

clear all 
set more off

cd "C:\Users\tianc\OneDrive\Documents\SIG\DISES\code\MPI"
*** Working Folder Path ***
global path_in "../../data/DHS/Cambodia/STATA" 	  


*** Cambodia DHS 2000 ***

use "$path_in/KHPR42DT/KHPR42FL.DTA", clear 
lookfor salt
codebook hv234 sh35
tab sh35, freq


*** Cambodia DHS 2005 ***

use "$path_in/KHPR51DT/KHPR51FL.DTA", clear 
codebook hv234*
tab hv234x, freq

use hv234* using "$path_in/KHHR51DT/KHHR51FL.DTA", clear 
codebook hv234*

use "$path_in/KHBR51DT/KHBR51FL.DTA", clear 
codebook v166*


*** Cambodia DHS 2010 ***

use "$path_in/KHPR61DT/KHPR61FL.DTA", clear 
codebook sh140 sh141
tab sh140, freq

use "$path_in/KHHR61DT/KHHR61FL.DTA", clear 
codebook sh140 sh141

use "$path_in/KHBR51DT/KHBR51FL.DTA", clear 
codebook v166*


*** Cambodia DHS 2014 ***

use "$path_in/KHPR73DT/KHPR73FL.DTA", clear 
codebook hv234* sh141
tab hv234a

use "$path_in/KHHR73DT/KHHR73FL.DTA", clear 
codebook hv234* sh141

use "$path_in/KHBR51DT/KHBR51FL.DTA", clear 
codebook v166*
