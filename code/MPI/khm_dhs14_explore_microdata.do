clear all 

cd "C:\Users\tianc\OneDrive\Documents\SIG\DISES\code\MPI"
// Working Folder Path
global path_data "../../data/MPI/dta"

use "$path_data/khm_dhs14.dta", clear  // 47,917 rows 

browse

describe

summarize

// hh member recode
use "$path_data/../../DHS/Cambodia/STATA/KHPR73DT/KHPR73FL.dta"  // 74,122 rows