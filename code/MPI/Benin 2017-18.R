########################################################################################################################
##
## Human Development Report Office (HDRO), United Nations Development Programme
## Multidimensional Poverty Index (MPI) 2020 release
##
## This code calculates the MPI and its component using the 2017/2018 DHS data for Benin.
## Users should first download the DHS data available at https://dhsprogram.com/data/available-datasets.cfm
## Users should also download the macro packages from WHO that calculates anthropometric z scores for children under 5 years (https://www.who.int/childgrowth/software/en/) 
## and for older boys and girls 15-19 years (https://www.who.int/growthref/tools/en/). Please follow WHO instructions.
## The WHO macro for R produces z scores that are slightly different in comparison with the z scores calculated in Stata. This is manually fixed in lines 214-228 below.
## WHO will update the macro in R, after this is done, the manual correction will not be necessary.
## 
## For now, MPI programs in R are available for 4 selected countries (Benin, Republic of Congo, India and Iraq). 
## This is still an experimental phase and HDRO plans to expand the availability of such programs. 
## However, users can adapt any of the MPI codes in R and produce programs for other countries. The modifications will depend on the information collected in the data for the other countries.
## We welcome feedback from the users. 
########################################################################################################################
  
### Set-up ### 
rm(list=ls())             # Clean up the environment
options(scipen=6)         # Display digits, not the scientific version
par(mfrow=c(1,1))         # Reset plot placement to normal 1 by 1
options(warn = -1)

### Working Folder Path ###

path_in <- "C:/Users/cecilia.calderon/Documents/HDRO_MCC/MPI/MPI 2.0/Kathrin consultancy R/Benin/"
path_out <- "C:/Users/cecilia.calderon/Documents/HDRO_MCC/MPI/MPI 2.0/Kathrin consultancy R/Benin/"
path_logs <- "C:/Users/cecilia.calderon/Documents/HDRO_MCC/MPI/MPI 2.0/Kathrin consultancy R/Benin/"
path_pc <- "C:/Users/cecilia.calderon/Documents/HDRO_MCC/MPI/MPI 2.0/Kathrin consultancy R/Benin/"


### Log file ### 
#sink(file.path(path_logs,"ben_dhs18_dataprep.txt"), split = TRUE)

### WHO2007 R macro package ###
# https://www.who.int/growthref/tools/readme_r.pdf?ua=1
wfawho2007<-read.table(file.path(path_in,"wfawho2007.txt"),header=T,sep="",skip=0)
hfawho2007<-read.table(file.path(path_in,"hfawho2007.txt"),header=T,sep="",skip=0) 
bfawho2007<-read.table(file.path(path_in,"bfawho2007.txt"),header=T,sep="",skip=0) 
source(file.path(path_in,"who2007.r"))

### Packages ###
# install.packages(c("haven", "Hmisc", "plyr", "memisc", "expss", "questionr", "anthro", "survey"))
library(haven)      # ready in dta file
library(Hmisc)      # to label variables
library(plyr)       # used for desc
library(memisc)     # command as codebook
library(expss)      # table with label
library(questionr)  # lookfor command
library(anthro)     # https://www.who.int/childgrowth/software/en/
library(survey)     # takes survey design into account    

########################################################################################################################
### Benin DHS 2017-18                                                                                                ###
########################################################################################################################
  
  
########################################################################################################################
### Step 1: Data preparation 
### Selecting variables from KR, BR, IR, & MR recode & merging with PR recode 
########################################################################################################################
# In Benin DHS 2017-18, height and weight measurements were collected from children (0-5) in 100% of sample and for women 
# (15-49) in 50% of the sample. We use 100% of sample for MPI.


########################################################################################################################
### Step 1.1 KR - CHILDREN's RECODE (under 5)
########################################################################################################################
DataKR <- read_stata(file.path(path_in, "BJPR71FL.DTA"))
### Generate individual unique key variable required for data merging
### hv001=cluster number; 
### hv002=household number; 
### hvidx=household line number in household

DataKR$ind_id <- DataKR$hv001*1000000 + DataKR$hv002*100 + DataKR$hvidx
label(DataKR$ind_id) <- "Individual ID"
str(DataKR$ind_id)

anyDuplicated(DataKR$ind_id) 

DataKR <- subset(DataKR, hv120 == 1) 

DataKR$child_KR <- 1 
	  #Generate identification variable for observations in KR recode

### Next check the variables that WHO needs to calculate the z-scores:
### sex, age, weight, height

### Variable: SEX ###
table(DataKR$hv104, useNA = "always")
    ### "1" for male ;"2" for female
DataKR$gender <- DataKR$hv104 
str(DataKR$gender)
table(DataKR$gender, useNA = "always")


### Variable: AGE ###
table(DataKR$hc1, useNA = "always")
codebook(DataKR$hc1)
    # Age is measured in months
DataKR$age_months <- DataKR$hc1
describe(DataKR$age_months)
summary(DataKR$age_months)
DataKR$ageunit <- "months"
label(DataKR$ageunit) <- "Months"
DataKR$mdate <- as.Date(paste(DataKR$hc18, DataKR$hc17, DataKR$hc19, sep = "/"), format = "%m/%d/%Y")
DataKR$bdate <- as.Date(paste(DataKR$hc30, DataKR$hc16, DataKR$hc31, sep = "/"), format = "%m/%d/%Y")
DataKR$bdate[which(DataKR$hc16>31)] <- as.Date(paste(DataKR$hc30, 15, DataKR$hc31, sep = "/"), format = "%m/%d/%Y")
      # Calculate birth date in days from date of interview
DataKR$age <- (as.numeric(DataKR$mdate) - as.numeric(DataKR$bdate))/30.4375
    # Calculate age in months 

DataKR$age2 <- DataKR$hc1a/30.4375
DataKR$comapre <- ifelse(DataKR$age == DataKR$age2,0,1)
table(DataKR$comapre, useNA = "always")
DataKR$age2 <- NULL


### Variable: BODY WEIGHT (KILOGRAMS) ###
describe(DataKR$hc2)
table(DataKR$hc2, useNA = "always")
DataKR$weight <- DataKR$hc2/10 
    # We divide it by 10 in order to express it in kilograms 
table(DataKR$hc2[DataKR$hc2>9990], useNA = "always")  
    # Missing values are 9994 to 9996
DataKR$weight[DataKR$hc2>=9990] <- NA 
    # All missing values or out of range are replaced as "NA"
table(DataKR$hc13[DataKR$hc2>=9990], DataKR$hc2[DataKR$hc2>=9990], useNA = "always")
    # hc13: result of the measurement
describe(DataKR$weight) 
summary(DataKR$weight)


### Variable: HEIGHT (CENTIMETERS) ###
describe(DataKR$hc3)
table(DataKR$hc3, useNA = "always")
DataKR$height <- DataKR$hc3/10
    # We divide it by 10 in order to express it in centimeters
table(DataKR$hc3[DataKR$hc3>9990], useNA = "always")  
    # Missing values are 9994 to 9996
DataKR$height[DataKR$hc3>=9990] <- NA 
    # All missing values or out of range are replaced as "NA"
table(DataKR$hc13[DataKR$hc3>=9990], DataKR$hc3[DataKR$hc3>=9990], useNA = "always")
describe(DataKR$height) 
summary(DataKR$height)


### Variable: MEASURED STANDING/LYING DOWN ###
describe(DataKR$hc15)  
DataKR$measure[DataKR$hc15==1] <- "l" 
    # Child measured lying down
DataKR$measure[DataKR$hc15==2] <- "h" 
    # Child measured standing up
DataKR$measure[DataKR$hc15==9 | DataKR$hc15==0] <- NA 
    # Replace with "NA" if unknown
describe(DataKR$measure)
table(DataKR$measure, useNA = "always")


### Variable: OEDEMA ###
lookfor(DataKR, "oedema")
DataKR$oedema <- "n"  
    # It assumes no-one has oedema
describe(DataKR$oedema)
table(DataKR$oedema, useNA = "always")	


### Variable: INDIVIDUAL CHILD SAMPLING WEIGHT ### 
DataKR$sw <- DataKR$hv005/1000000 
    # For DHS sample weight has to be divided 1000000
describe(DataKR$sw)
summary(DataKR$sw)


# We now run the command to calculate the z-scores with the R-Command #
children_nutri_ben_z_rc <- with(DataKR, anthro_zscores
                                        (sex = gender, 
                                         age = age, 
                                         is_age_in_month = TRUE, 
                                         weight = weight,
                                         lenhei = height,
                                         oedema = oedema
                                         )
                              )


### Standard MPI indicator ### 
    # Takes value 1 if the child is under 2 stdev below the median & 0 otherwise
children_nutri_ben_z_rc$underweight <- ifelse(children_nutri_ben_z_rc$zwei < -2.0,1,0)
children_nutri_ben_z_rc$underweight[is.na(children_nutri_ben_z_rc$zwei)] <- 0
children_nutri_ben_z_rc$underweight[is.na(children_nutri_ben_z_rc$zwei) | children_nutri_ben_z_rc$fwei == 1] <- NA
label(children_nutri_ben_z_rc$underweight) <- "Child is undernourished (weight-for-age) 2sd - WHO"
table(children_nutri_ben_z_rc$underweight, useNA = "always")

children_nutri_ben_z_rc$stunting <- ifelse(children_nutri_ben_z_rc$zlen < -2.0,1,0)
children_nutri_ben_z_rc$stunting[is.na(children_nutri_ben_z_rc$zlen)] <- 0
children_nutri_ben_z_rc$stunting[is.na(children_nutri_ben_z_rc$zlen) | children_nutri_ben_z_rc$flen == 1] <- NA
label(children_nutri_ben_z_rc$stunting) <- "Child is stunted (length/height-for-age) 2sd - WHO"
table(children_nutri_ben_z_rc$stunting, useNA = "always")

children_nutri_ben_z_rc$wasting <- ifelse(children_nutri_ben_z_rc$zwfl < -2.0,1,0)
children_nutri_ben_z_rc$wasting[is.na(children_nutri_ben_z_rc$zwfl)] <- 0
children_nutri_ben_z_rc$wasting[is.na(children_nutri_ben_z_rc$zwfl) | children_nutri_ben_z_rc$fwfl == 1] <- NA
label(children_nutri_ben_z_rc$wasting) <- "Child is wasted (weight-for-length/height) 2sd - WHO"
table(children_nutri_ben_z_rc$wasting, useNA = "always")


# Retain relevant variables:
ben18_KR <- cbind(children_nutri_ben_z_rc,DataKR)
ben18_KR <- ben18_KR[c("underweight", "stunting", "wasting", "ind_id", "child_KR")] 
rm("children_nutri_ben_z_rc")

# comparing the results of R and Stata shows that stunting has slightly different results in R for the observations
# for stunting
# ind_id == 7002503
# ind_id == 179009905
# ind_id == 227006203
#
# for wasting
# ind_id == 113007405
# XXX correct when solved problem 

# remove after fxing
 ben18_KR$stunting[ben18_KR$ind_id==7002503] <- 0
 ben18_KR$stunting[ben18_KR$ind_id==179009905] <- 0
 ben18_KR$stunting[ben18_KR$ind_id==227006203] <- 0
 ben18_KR$wasting[ben18_KR$ind_id==113007405] <- 1

ben18_KR[order(ben18_KR$ind_id),] 
anyDuplicated(ben18_KR$ind_id) 


########################################################################################################################
### Step 1.2  BR - BIRTH RECODE
### (All females 15-49 years who ever gave birth) 
########################################################################################################################
DataBR <- read_stata(file.path(path_in, "BJBR71FL.DTA"))

### Generate individual unique key variable required for data merging
### v001=cluster number; 
### v002=household number; 
### v003=respondent's line number

DataBR$ind_id <- DataBR$v001*1000000 + DataBR$v002*100 + DataBR$v003
label(DataBR$ind_id) <- "Individual ID"
str(DataBR$ind_id)

describe(DataBR$b3)
describe(DataBR$b7)        
DataBR$date_death <- DataBR$b3 + DataBR$b7
    # Date of death = date of birth (b3) + age at death (b7)
DataBR$mdead_survey <-  DataBR$v008 - DataBR$date_death
    # Months dead from survey = Date of interview (v008) - date of death
DataBR$ydead_survey <- DataBR$mdead_survey/12
    # Years dead from survey

describe(DataBR$b5)
table(DataBR$b5, useNA = "always")
DataBR$child_died[DataBR$b5==0] <- 1
    # Redefine the coding and labels (1=child dead; 0=child alive)
DataBR$child_died[DataBR$b5==1] <- 0
DataBR$child_died[is.na(DataBR$b5)] <- NA
table(DataBR$b5, DataBR$child_died, useNA = "always")


# NOTE: For each woman, sum the number of children who died and compare to the number of sons/daughters 
# whom they reported have died 
DataBR$tot_child_died <- ave(DataBR$child_died, DataBR$ind_id, FUN = function(x) sum(x,na.rm=T))
DataBR$tot_child_died_2 <- DataBR$v206 + DataBR$v207
    # v206: sons who have died
    # v207: daughters who have died
DataBR$comapre <- ifelse(DataBR$tot_child_died == DataBR$tot_child_died_2,0,1)
table(DataBR$comapre, useNA = "always")
    # In Benin DHS 2017-18, these figures are identical
DataBR$child_died[DataBR$b7>=216] <- 0
    # counting only deaths of children <18y (216 months)

DataBR$temp[DataBR$ydead_survey<=5 & DataBR$child_died ==1] <- 1
DataBR$temp[DataBR$ydead_survey>5 & DataBR$child_died ==1] <- 0
DataBR$temp[DataBR$child_died ==0] <- 0
DataBR$tot_child_died_5y <- ave(DataBR$temp, DataBR$ind_id, FUN = function(x) sum(x,na.rm=T))

DataBR$child_died_per_wom <- ave(DataBR$tot_child_died, DataBR$ind_id, FUN =  function(x) max(x,na.rm=T)) 
label(DataBR$child_died_per_wom) <- "Total child death for each women (birth recode)"

DataBR$child_died_per_wom_5y <- ave(DataBR$tot_child_died_5y, DataBR$ind_id, FUN = function(x) max(x,na.rm=T)) 
label(DataBR$child_died_per_wom_5y) <- "Total child death for each women in the last 5 years (birth recode)"


#Keep one observation per women
DataBR[order(DataBR$ind_id),] 
DataBR<- DataBR[!duplicated(DataBR$ind_id), ]

DataBR$women_BR <- 1 
    # Identification variable for observations in BR recode


#Retain relevant variables
ben18_BR <- DataBR[c("ind_id", "women_BR", "b16", "child_died_per_wom",
                    "child_died_per_wom_5y", "b7")]

	
########################################################################################################################
### Step 1.3  IR - WOMEN's RECODE  
### (All eligible females 15-49 years in the household)
######################################################################################################################## 
DataIR <- read_stata(file.path(path_in, "BJIR71FL.DTA" ))

### Generate individual unique key variable required for data merging
### v001=cluster number; 
### v002=household number; 
### v003=respondent's line number

DataIR$ind_id <- DataIR$v001*1000000 + DataIR$v002*100 + DataIR$v003
label(DataIR$ind_id) <- "Individual ID"
str(DataIR$ind_id) 

anyDuplicated(DataIR$ind_id) 

DataIR$women_IR <- 1 
    # Identification variable for observations in IR recode

DataIR[order(DataIR$ind_id),] 
ben18_IR <- DataIR[c("ind_id", "women_IR", "v003", "v005", "v012", "v201", "v206", "v207")]
    # Save a temp file for merging with PR


########################################################################################################################
### Step 1.4  IR - WOMEN'S RECODE  
### (Girls 15-19 years in the household)
########################################################################################################################
DataPR <- read_stata(file.path(path_in, "BJPR71FL.DTA" ))

### Generate individual unique key variable required for data merging
### hv001=cluster number; 
### hv002=household number; 
### hvidx=householdline number

DataPR$ind_id <- DataPR$hv001*1000000 + DataPR$hv002*100 + DataPR$hvidx 
label(DataPR$ind_id) <- "Individual ID"
str(DataPR$ind_id) 

anyDuplicated(DataPR$ind_id) 

DataPR <- subset(DataPR, hv104==2 & hv105>=15 & hv105<=19 & hv042==1)


### Variables required to calculate the z-scores to produce BMI-for-age:

### Variable: SEX ###
DataPR$gender <- 2 


### Variable: AGE IN MONTHS ###
DataPR$comapre <- ifelse(DataPR$hv807c==DataPR$hv008,0,1)
table(DataPR$comapre, useNA = "always")
    #date of biomarker vs date of interview, they should be identical

DataPR$age_month <- DataPR$hv807c - DataPR$ha32
label(DataPR$age_month) <- "Age in months, individuals 15-19 years"	


###  Variable: AGE UNIT ### 
DataPR$ageunit <- "months" 
label(DataPR$ageunit) <- "Months"


# Calculate age in months 
### Variable: BODY WEIGHT (KILOGRAMS) ###
describe(DataPR$ha2)
table(DataPR$ha2, useNA = "always")
DataPR$weight = DataPR$ha2/10
    # We divide it by 10 in order to express it in kilograms
DataPR$weight[DataPR$ha2>=9990] <- NA 
    # All missing values or out of range are replaced as "."
summary(DataPR$weight)


### Variable: HEIGHT (CENTIMETERS) ###
describe(DataPR$ha3)
table(DataPR$ha3, useNA = "always")
DataPR$height = DataPR$ha3/10 
    # We divide it by 10 in order to express it in centimeters
DataPR$height[DataPR$ha3>9990] <- NA 
    # All missing values or out of range are replaced as "."
summary(DataPR$height)


### Variable: OEDEMA ***
lookfor(DataPR, "oedema")
DataPR$oedema <- "n"  
# It assumes no-one has oedema
describe(DataPR$oedema)
table(DataPR$oedema, useNA = "always")	


### Variable: SAMPLING WEIGHT ### 
DataPR$sw <- DataPR$hv005/1000000 
# For DHS sample weight has to be divided 1000000
summary(DataPR$sw)
DataPR <- as.data.frame(DataPR)

# We now run the command to calculate the z-scores with the R-Command #
who2007(FilePath="C:/Users/kathrin/Desktop/Consultancy",
                            FileLab = "girl_nutri_ben_z",
                            mydf=DataPR,
                            sex=gender,
                            age=age_month,
                            weight=weight,
                            height=height,
                            oedema=oedema,
                            sw=sw)

girl_nutri_ben_z <- read.csv(file.path(path_in, "girl_nutri_ben_z_z.csv"))

### Standard MPI Indicator ###
girl_nutri_ben_z$z_bmi <- girl_nutri_ben_z$zbfa
girl_nutri_ben_z$z_bmi[girl_nutri_ben_z$fbfa==1] <- NA
label(girl_nutri_ben_z$z_bmi) <- "z-score bmi-for-age WHO"

girl_nutri_ben_z$low_bmiage <- ifelse(girl_nutri_ben_z$z_bmi < -2.0,1,0) 
    # Takes value 1 if BMI-for-age is under 2 stdev below the median & 0 otherwise
girl_nutri_ben_z$low_bmiage[is.na(girl_nutri_ben_z$z_bmi)] <- NA
label(girl_nutri_ben_z$low_bmiage) <- "Teenage low bmi 2sd - WHO"

girl_nutri_ben_z$teen_IR <- 1
    # Identification variable for observations in IR recode (only 15-19 years)	


#Retain relevant variables:	
ben18_IR_girls <- girl_nutri_ben_z[c("ind_id", "teen_IR", "age_month", "low_bmiage")]
rm("girl_nutri_ben_z")
ben18_IR_girls[order(ben18_IR_girls$ind_id),] 


 
########################################################################################################################
### Step 1.5  MR - MEN'S RECODE  
### (All eligible man: 15-64 years in the household) 
########################################################################################################################  
DataMR <- read_stata(file.path(path_in, "BJMR71FL.DTA"))

### Generate individual unique key variable required for data merging
### mv001=cluster number; 
### mv002=household number; 
### mv003=respondent's line number

DataMR$ind_id <- DataMR$mv001*1000000 + DataMR$mv002*100 + DataMR$mv003
label(DataMR$ind_id) <- "Individual ID"
str(DataMR$ind_id) 

anyDuplicated(DataMR$ind_id) 

DataMR$men_MR <- 1 	
    # Identification variable for observations in MR recode

DataMR[order(DataMR$ind_id),] 
ben18_MR <- DataMR[c("ind_id", "men_MR", "mv003", "mv005", "mv012", "mv201", "mv206", "mv207")]
    # Save a temp file for merging with PR:


########################################################################################################################  
### Step 1.6a  MR - MEN'S RECODE  
### (Boys 15-19 years in the household) 
########################################################################################################################  
# Note: In the case of Benin 2017-18, anthropometric data was not collected for men.
DataMR <- read_stata(file.path(path_in, "BJMR71FL.DTA"))

### Generate individual unique key variable required for data merging
### mv001=cluster number; 
### mv002=household number; 
### mv003=respondent's line number

DataMR$ind_id <- DataMR$mv001*1000000 + DataMR$mv002*100 + DataMR$mv003
label(DataMR$ind_id) <- "Individual ID"
str(DataMR$ind_id) 

anyDuplicated(DataMR$ind_id) 

DataMR$age_month_boys <-  NA

DataMR$low_bmiage_boys <- NA
label(DataMR$low_bmiage_boys) <- "Teenage low bmi 2sd - WHO"

DataMR <- subset(DataMR, mv012>=15 & mv012<=19)
    # Keep only boys between age 15-19 years to compute BMI-for-age

DataMR$teen_MR <-1


#Retain relevant variables:	
DataMR[order(DataMR$ind_id),] 
ben18_MR_boys <- DataMR[c("ind_id", "teen_MR", "age_month_boys", "low_bmiage_boys")]
    # Save a temp file for merging with PR


########################################################################################################################
### Step 1.7  PR - HOUSEHOLD MEMBER'S RECODE 
########################################################################################################################
DataPR <- read_stata(file.path(path_in, "BJPR71FL.DTA"))

DataPR$cty <- "Benin" 
DataPR$ccty <- "BEN"  
DataPR$year <- "2017-18"  
DataPR$survey <- "DHS"
DataPR$ccnum <- 204

### Generate a household unique key variable at the household level using: 
### hv001=cluster number 
### hv002=household number
DataPR$hh_id <- DataPR$hv001*10000 + DataPR$hv002 
label(DataPR$hh_id) <- "Household ID"
describe(DataPR$hh_id)  


### Generate individual unique key variable required for data merging using:
### hv001=cluster number; 
### hv002=household number; 
### hvidx=respondent's line number.
DataPR$ind_id = DataPR$hv001*1000000 + DataPR$hv002*100 + DataPR$hvidx 
label(DataPR$ind_id) <- "Individual ID"
describe(DataPR$ind_id)

DataPR[order(c(DataPR$hh_id, DataPR$ind_id)),] 



########################################################################################################################
### 1.8 DATA MERGING
########################################################################################################################

### Merging BR Recode 
#########################################
data_merge_1 <- merge(DataPR, ben18_BR,by="ind_id", all=TRUE)
rm("ben18_BR")


### Merging IR Recode 
#########################################
data_merge_2 <- merge(data_merge_1, ben18_IR, by="ind_id", all=TRUE)
rm("ben18_IR")

table(data_merge_2$women_IR, data_merge_2$hv117, useNA = "always")
table(data_merge_2$ha65[data_merge_2$hv117==1 & is.na(data_merge_2$women_IR)], useNA = "always")
    # Total number of eligible women not interviewed
table(data_merge_2$ha65[is.na(data_merge_2$women_IR) & data_merge_2$hv117==1], 
      data_merge_2$ha13[is.na(data_merge_2$women_IR) & data_merge_2$hv117==1], useNA ="always")  


### Merging IR Recode: 15-19 years girls 
#########################################
data_merge_3 <- merge(data_merge_2, ben18_IR_girls, by="ind_id", all=TRUE)
rm("ben18_IR_girls")

table(data_merge_3$teen_IR[data_merge_3$hv105>=15 & data_merge_3$hv105<=19 & data_merge_3$hv042==1],
      data_merge_3$hv117[data_merge_3$hv105>=15 & data_merge_3$hv105<=19 & data_merge_3$hv042==1], useNA ="always")


### Merging MR Recode 
#########################################
data_merge_4 <- merge(data_merge_3, ben18_MR, by="ind_id", all=TRUE)
rm("ben18_MR")

table(data_merge_4$men_MR, data_merge_4$hv118, useNA = "always")


### Merging MR Recode: 15-19 years boys 
#########################################
data_merge_5 <- merge(data_merge_4, ben18_MR_boys, by="ind_id", all=TRUE)
rm("ben18_MR_boys")


### Merging KR Recode 
#########################################
data_merge_6 <- merge(data_merge_5, ben18_KR, by="ind_id", all=TRUE)
rm("ben18_KR")

DataFinal <- data_merge_6
rm("data_merge_1", "data_merge_2","data_merge_3","data_merge_4","data_merge_5")
rm("DataBR", "DataIR","DataKR","DataMR","DataPR")

########################################################################################################################
### Step 1.9 KEEPING ONLY DE JURE HOUSEHOLD MEMBERS                       
########################################################################################################################
# Permanent (de jure) household members 
DataFinal$resident <- DataFinal$hv102 
describe(DataFinal$resident)
table(DataFinal$resident, useNA = "always")
label(DataFinal$resident) <- "Permanent (de jure) household member"


DataFinal <- subset(DataFinal, DataFinal$resident==1) 
table(DataFinal$resident, useNA = "always")
# Note: The Global MPI is based on de jure (permanent) household members only. As such, non-usual residents will be 
# excluded from the sample. In the context of Benin DHS 2017-18, 945 (1.27%) individuals who were non-usual residents 
# were dropped from the sample


########################################################################################################################
### 1.10 CONTROL VARIABLES
########################################################################################################################
# Households are identified as having 'no eligible' members if there are no applicable population, that is, children 0-5 
# years, adult women 15-49 years or men 15-64 years. These households will not have information on relevant indicators of 
# health. As such, these households are considered as non-deprived in those relevant indicators.


### No Eligible Women 15-49 years
#########################################
DataFinal$fem_eligible <- ifelse(DataFinal$hv117==1,1,0)
DataFinal$hh_n_fem_eligible <- ave(DataFinal$fem_eligible, DataFinal$hh_id, FUN = function(x) sum(x,na.rm=T))
    # Number of eligible women for interview in the hh
DataFinal$no_fem_eligible <- ifelse(DataFinal$hh_n_fem_eligible==0,1,0)
    # Takes value 1 if the household had no eligible females for an interview
label(DataFinal$no_fem_eligible) <- "Household has no eligible women"
table(DataFinal$no_fem_eligible, useNA = "always")


### No Eligible Men 15-64 years
#########################################
DataFinal$male_eligible <- ifelse(DataFinal$hv118==1,1,0)
DataFinal$hh_n_male_eligible <- ave(DataFinal$male_eligible, DataFinal$hh_id, FUN = function(x) sum(x,na.rm=T))
     # Number of eligible men for interview in the hh
DataFinal$no_male_eligible <- ifelse(DataFinal$hh_n_male_eligible==0,1,0)
    # Takes value 1 if the household had no eligible males for an interview
label(DataFinal$no_male_eligible) <- "Household has no eligible man"
table(DataFinal$no_male_eligible, useNA = "always")


### No Eligible Children 0-5 years
#########################################
DataFinal$child_eligible <- ifelse(DataFinal$hv120==1,1,0)
DataFinal$hh_n_children_eligible <- ave(DataFinal$child_eligible, DataFinal$hh_id, FUN = function(x) sum(x,na.rm=T))
    # Number of eligible children for anthropometrics
DataFinal$no_child_eligible <- ifelse(DataFinal$hh_n_children_eligible==0,1,0) 
    # Takes value 1 if there were no eligible children for anthropometrics
label(DataFinal$no_child_eligible) <- "Household has no children eligible"
table(DataFinal$no_child_eligible, useNA = "always")


### No Eligible Women and Men 
#########################################
# NOTE: In the DHS datasets, we use this variable as a control variable for the child mortality indicator if mortality 
# data was collected from women and men. If child mortality was only colelcted from women, the we use 'no_fem_eligible' 
# as the eligibility criteria 
DataFinal$no_adults_eligible <-ifelse(DataFinal$no_fem_eligible==1 & DataFinal$no_male_eligible==1,1,0) 
    # Takes value 1 if the household had no eligible men & women for an interview
label(DataFinal$no_adults_eligible) <- "Household has no eligible women or men"
table(DataFinal$no_adults_eligible, useNA = "always") 


### No Eligible Children and Women  
#########################################
# NOTE: In the DHS datasets, we use this variable as a control variable for the nutrition indicator if nutrition data 
# is present for children and women.
DataFinal$no_child_fem_eligible <- ifelse(DataFinal$no_child_eligible==1 & DataFinal$no_fem_eligible==1,1,0) 
label(DataFinal$no_child_fem_eligible) <- "Household has no children or women eligible"
table(DataFinal$no_child_fem_eligible, useNA = "always") 


### No Eligible Women, Men or Children 
#########################################
# NOTE: In the DHS datasets, we use this variable as a control variable for the nutrition indicator if nutrition data 
# is present for children, women and men.
DataFinal$no_eligibles <- ifelse(DataFinal$no_fem_eligible==1 & DataFinal$no_male_eligible==1 & DataFinal$no_child_eligible==1,1,0)
label(DataFinal$no_eligibles) <- "Household has no eligible women, men, or children"
table(DataFinal$no_eligibles, useNA = "always")


### No Eligible Subsample 
#########################################
# hv042 (household selected for hemoglobin) is essentially a variable that indicates whether there is selection of a 
# subsample for anthropometric data.	
DataFinal$hem_eligible <- ifelse(DataFinal$hv042==1,1,0) 
DataFinal$hh_n_hem_eligible <- ave(DataFinal$hem_eligible, DataFinal$hh_id, FUN = function(x) sum(x,na.rm=T))
DataFinal$no_hem_eligible <- ifelse(DataFinal$hh_n_hem_eligible==0,1,0) 
    # Takes value 1 if the HH had no eligible females for hemoglobin test	
label(DataFinal$no_hem_eligible) <- "Household has no eligible individuals for hemoglobin measurements"
table(DataFinal$no_hem_eligible, useNA ="always")


DataFinal <- DataFinal[!names(DataFinal) %in% c("fem_eligible", "hh_n_fem_eligible", "male_eligible", "hh_n_male_eligible",
                        "child_eligible", "hh_n_children_eligible", "hem_eligible", "hh_n_hem_eligible")]


########################################################################################################################
### 1.11 SUBSAMPLE VARIABLE 
########################################################################################################################
# In Benin DHS 2017-18, height and weight measurements were collected from children (0-5) in 100% of sample and for 
# women (15-49) in 50% of the sample. We use 100% of sample for MPI.
DataFinal$subsample <- 1
label(DataFinal$subsample) <- "Households selected as part of nutrition subsample" 
table(DataFinal$subsample, useNA = "always")


########################################################################################################################
### 1.12 RENAMING DEMOGRAPHIC VARIABLES ***
########################################################################################################################
# Sample weight
describe(DataFinal$hv005)
DataFinal$weight <- DataFinal$hv005 
label(DataFinal$weight) <- "Sample weight"


# Area: urban or rural	
describe(DataFinal$hv025)
str(DataFinal$hv025)
table(DataFinal$hv025, useNA = "always")
DataFinal$area <- DataFinal$hv025  
DataFinal$area[DataFinal$area==2] <- 0  
DataFinal$area <- factor(DataFinal$area,
                             levels = c(0,1),
                             labels = c("rural", "urban")) 
label(DataFinal$area) <- "Area: urban-rural"


# Relationship to the head of household 
DataFinal$relationship <- DataFinal$hv101 
describe(DataFinal$relationship)
table(DataFinal$relationship, useNA = "always")
DataFinal$relationship[DataFinal$relationship==11 | DataFinal$relationship== 14] <- 3
DataFinal$relationship[DataFinal$relationship>=4 & DataFinal$relationship<= 10] <- 4
DataFinal$relationship[DataFinal$relationship==12 | DataFinal$relationship== 13] <- 5
DataFinal$relationship <- factor(DataFinal$relationship,
                                  levels = c(1,2,3,4,5),
                                  labels = c("head", "spouse", "child", "extended family", "not related"))
label(DataFinal$relationship) <- "Relationship to the head of household"
table(DataFinal$hv101, DataFinal$relationship, useNA = "always")


# Sex of household member	
describe(DataFinal$hv104)
table(DataFinal$hv104, useNA = "always")
DataFinal$sex <- DataFinal$hv104  
label(DataFinal$sex) <- "Sex of household member"


# Age of household member
describe(DataFinal$hv105)
table(DataFinal$hv105, useNA = "always")
DataFinal$age <- DataFinal$hv105  
DataFinal$age[DataFinal$age>=98] <- NA
label(DataFinal$age) <- "Age of household member"


# Age group 
DataFinal$agec7[DataFinal$age>=0 & DataFinal$age<= 4] <- 1
DataFinal$agec7[DataFinal$age>=5 & DataFinal$age<= 9] <- 2
DataFinal$agec7[DataFinal$age>=10 & DataFinal$age<= 14] <- 3
DataFinal$agec7[DataFinal$age>=15 & DataFinal$age<= 17] <- 4
DataFinal$agec7[DataFinal$age>=18 & DataFinal$age<= 59] <- 5
DataFinal$agec7[DataFinal$age>=60] <- 6
DataFinal$agec7 <- factor(DataFinal$agec7,
                                 levels = c(1,2,3,4,5,6),
                                 labels = c("0-4", "5-9", "10-14", "15-17", "18-59", "60+"))
label(DataFinal$agec7) <- "age groups (7 groups)"	
DataFinal$agec4[DataFinal$age>=0 & DataFinal$age<= 9] <- 1
DataFinal$agec4[DataFinal$age>=10 & DataFinal$age<= 17] <- 2
DataFinal$agec4[DataFinal$age>=18 & DataFinal$age<= 59] <- 3
DataFinal$agec4[DataFinal$age>=60] <- 4
DataFinal$agec4 <- factor(DataFinal$agec4,
                          levels = c(1,2,3,4),
                          labels = c("0-9", "10-17", "18-59", "60+"))
label(DataFinal$agec4) <- "age groups (4 groups)"


# Marital status of household member
DataFinal$marital <- DataFinal$hv115 
describe(DataFinal$marital)
table(DataFinal$marital, useNA = "always")
DataFinal$marital[DataFinal$marital==1] <- 2
DataFinal$marital[DataFinal$marital==0] <- 1
DataFinal$marital[DataFinal$marital==8] <- NA
DataFinal$marital <- factor(DataFinal$marital,
                          levels = c(1,2,3,4,5),
                          labels = c("never married", "currently married", "widowed", "divorced", "not living together"))
label(DataFinal$marital) <- "Marital status of household member"
table(DataFinal$hv115, DataFinal$marital, useNA = "always")


# Total number of de jure hh members in the household
DataFinal$member <- 1
DataFinal$hhsize <- ave(DataFinal$member, DataFinal$hh_id, FUN = function(x) sum(x,na.rm=T))
label(DataFinal$hhsize) <- "Household size"
table(DataFinal$hhsize, useNA = "always")
DataFinal$member <- NULL


# Subnational region
lookfor(DataFinal, "region")
describe(DataFinal$hv024)
table(DataFinal$hv024, useNA = "always")	
DataFinal$region <- DataFinal$hv024
label(DataFinal$region) <- "Region for subnational decomposition"

table(DataFinal$hv024, DataFinal$region, useNA="always")


########################################################################################################################
###  Step 2 Data preparation  
###  Standardization of the 10 Global MPI indicators 
###  Identification of non-deprived & deprived individuals  
########################################################################################################################

########################################################################################################################
### Step 2.1 Years of Schooling 
########################################################################################################################
describe(DataFinal$hv108)
table(DataFinal$hv108, useNA = "always")
DataFinal$eduyears <- DataFinal$hv108   
    # total number of years of education
DataFinal$eduyears[DataFinal$eduyears>30] <- NA 
    # recode any unreasonable years of highest education as missing value
DataFinal$eduyears[DataFinal$eduyears>=DataFinal$age & DataFinal$age>0] <- NA 
DataFinal$eduyears[DataFinal$age<10] <- 0 
# The variable "eduyears" was replaced with a '0' given that the criteria for this indicator is household member aged 
# 10 years or older


# A control variable is created on whether there is information on years of education for at least 2/3 of the household 
# members.
DataFinal[order(c(DataFinal$hh_id)),] 
DataFinal$temp[!is.na(DataFinal$age) & DataFinal$age>=10] <- 1 
DataFinal$temp[is.na(DataFinal$eduyears)] <- NA 
DataFinal$no_missing_edu <- ave(DataFinal$temp, DataFinal$hh_id,  FUN = function(x) sum(x,na.rm=T))
    # Total household members who are 10 years and older with no missing years of education
DataFinal$temp2[DataFinal$age>=10 & !is.na(DataFinal$age)] <- 1
DataFinal$hhs <- ave(DataFinal$temp2, DataFinal$hh_id,  FUN = function(x) sum(x,na.rm=T))
    # Total number of household members who are 10 years and older 
DataFinal$no_missing_edu <- (DataFinal$no_missing_edu) / (DataFinal$hhs)
DataFinal$no_missing_edu <- ifelse(DataFinal$no_missing_edu>=2/3,1,0)
    # Identify whether there is information on years of education for at least 2/3 of the household members aged 10 
    # years and older
table(DataFinal$no_missing_edu, useNA = "always")
label(DataFinal$no_missing_edu) <- "No missing edu for at least 2/3 of the HH members aged 10 years & older"		
DataFinal <- DataFinal[!names(DataFinal) %in% c("temp", "temp2", "hhs")]

# The entire household is considered deprived if no household member aged 10 years or older has completed SIX years of 
# schooling. 

DataFinal$years_edu6 <- ifelse(DataFinal$eduyears>=6,1,0)
# The years of schooling indicator takes a value of "1" if at least someone in the hh has reported 6 years of education 
# or more 
DataFinal$years_edu6[is.na(DataFinal$eduyears)] <- NA
DataFinal$hh_years_edu6_1 <- ave(DataFinal$years_edu6, DataFinal$hh_id,  FUN = function(x) max(x,na.rm=T)) # max
DataFinal$hh_years_edu6 <- ifelse(DataFinal$hh_years_edu6_1==1,1,0)
DataFinal$hh_years_edu6[is.na(DataFinal$hh_years_edu6_1)] <- NA
DataFinal$hh_years_edu6[DataFinal$hh_years_edu6==0 & DataFinal$no_missing_edu==0] <- NA
label(DataFinal$hh_years_edu6) <- "Household has at least one member with 6 years of edu"


########################################################################################################################
### Step 2.2 Child School Attendance 
########################################################################################################################
describe(DataFinal$hv121)
table(DataFinal$hv121, useNA = "always")
DataFinal$attendance <- DataFinal$hv121 
DataFinal$attendance[DataFinal$attendence==2] <- 1
describe(DataFinal$attendance)
table(DataFinal$attendance, useNA = "always")

DataFinal$attendance[(DataFinal$attendance==9 | is.na(DataFinal$attendance)) & DataFinal$hv109==0] <- 0  
      # In some countries, they don't assess attendance for those with no educational attainment. These are replaced with
      # a '0'
DataFinal$attendance[DataFinal$attendance==9 & DataFinal$hv109!=0] <- NA
      # Replace missing values


### Old & New Standard MPI 
###############################################################################
# The entire household is considered deprived if any school-aged child is not attending school up to class 8. 
DataFinal$child_schoolage <- ifelse(DataFinal$age>=6 & DataFinal$age<=14,1,0) 
    # Note: In Benin, the official school entrance age is 7 years.So, age range is 6-14 (=6+8)
    # Source: http://data.uis.unesco.org/?ReportId=163. */
  
  
# A control variable is created on whether there is no information on school attendance for at least 2/3 of the school 
# age children 
sum(DataFinal$child_schoolage==1 & is.na(DataFinal$attendance), na.rm=TRUE)
    # Understand how many eligible school aged children are not attending school 
DataFinal$temp <- ifelse(DataFinal$child_schoolage==1 | is.na(DataFinal$attendance),1,0) 
    # Generate a variable that captures the number of eligible school aged children who are attending school 
DataFinal$no_missing_atten <- ave(DataFinal$temp, DataFinal$hh_id, FUN = function(x) sum(x,na.rm=T))
	  # Total school age children with no missing information on school attendance 
DataFinal$temp2 <- ifelse(DataFinal$child_schoolage==1,1,0)
DataFinal$hhs <- ave(DataFinal$temp2, DataFinal$hh_id, FUN = function(x) sum(x,na.rm=T))
    # Total number of household members who are of school age
DataFinal$no_missing_atten <- (DataFinal$no_missing_atten)/(DataFinal$hhs) 
DataFinal$no_missing_atten <- ifelse(DataFinal$no_missing_atten>=2/3,1,0)
DataFinal$no_missing_atten[is.na(DataFinal$no_missing_atten)] <- 1
    # Identify whether there is missing information on school attendance for more than 2/3 of the school age children 			
table(DataFinal$no_missing_atten, useNA = "always")
label(DataFinal$no_missing_atten) <- "No missing school attendance for at least 2/3 of the school aged children"		
DataFinal <- DataFinal[!names(DataFinal) %in% c("temp", "temp2", "hhs")]


DataFinal$hh_children_schoolage <- ave(DataFinal$child_schoolage, DataFinal$hh_id, FUN = function(x) sum(x,na.rm=T))
DataFinal$hh_children_schoolage <- ifelse(DataFinal$hh_children_schoolage>0,1,0) 
    # Control variable: It takes value 1 if the household has children in school age
label(DataFinal$hh_children_schoolage) <- "Household has children in school age"


DataFinal$child_not_atten <- ifelse(DataFinal$attendance==0 & DataFinal$child_schoolage==1,1,0) 
DataFinal$child_not_atten[is.na(DataFinal$attendance) & DataFinal$child_schoolage==1] <- NA
DataFinal$any_child_not_atten <- ave(DataFinal$child_not_atten, DataFinal$hh_id, FUN = function(x) max(x,na.rm=T))
DataFinal$hh_child_atten <- ifelse(DataFinal$any_child_not_atten==0,1,0)
DataFinal$hh_child_atten[is.na(DataFinal$any_child_not_atten)] <- NA
DataFinal$hh_child_atten[DataFinal$hh_children_schoolage==0] <- 1
DataFinal$hh_child_atten[DataFinal$hh_child_atten==1 & DataFinal$no_missing_atten==0] <- NA 
    # If the household has been intially identified as non-deprived, but has missing school attendance for at least 2/3
    # of the school aged children, then we replace this household with a value of '.' because there is insufficient 
    # information to conclusively conclude that the household is not deprived
label(DataFinal$hh_child_atten) <- "Household has all school age children up to class 8 in school"
table(DataFinal$hh_child_atten, useNA = "always")

# Note: The indicator takes value 1 if ALL children in school age are attending school and 0 if there is at least one 
# child not attending. Households with no children receive a value of 1 as non-deprived. The indicator has a missing 
# value only when there are all missing values on children attendance in households that have children in school age. 
  
  
########################################################################################################################
### Step 2.3 Nutrition 
########################################################################################################################

########################################################################################################################
### Step 2.3a Adult Nutrition 
########################################################################################################################
# Note: Benin DHS 2017-18 does not have anthropometric data for men 
lookfor(DataFinal, "body")  
lookfor(DataFinal, "mass")
describe(DataFinal$ha40)


### ELIGIBILITY FOR BMI ###

### WOMEN
##############################################
DataFinal$fem_eligible_bmi <- ifelse(!is.na(DataFinal$ha13),1,0)
DataFinal$fem_eligible_bmi[DataFinal$age>49 & !is.na(DataFinal$age)] <- 0  
DataFinal$hh_n_fem_eligible_bmi <- ave(DataFinal$fem_eligible_bmi, DataFinal$hh_id, FUN = function(x) sum(x,na.rm=T))
    # Number of eligible women for BMI in the hh
DataFinal$no_fem_eligible_bmi <- ifelse(DataFinal$hh_n_fem_eligible_bmi==0,1,0)
    # Takes value 1 if the household had no eligible females for an interview
label(DataFinal$no_fem_eligible_bmi) <- "Household has no eligible women"
table(DataFinal$no_fem_eligible_bmi, useNA = "always")


### No Eligible Women or Children for BMI
##############################################
# NOTE: In the DHS datasets, we use this variable as a control variable for the nutrition indicator if nutrition data 
# is present for children, women and men. 
DataFinal$no_eligibles_bmi <- ifelse(DataFinal$no_fem_eligible_bmi==1 & DataFinal$no_child_eligible==1,1,0)
label(DataFinal$no_eligibles_bmi) <- "Household has no eligible women or children for BMI"
table(DataFinal$no_eligibles_bmi, useNA = "always")


### BMI Indicator for Women 15-49 years 
############################################## 
DataFinal$f_bmi <- DataFinal$ha40/100
    # Low BMI of women 15-49 years	
label(DataFinal$f_bmi) <- "Women's BMI"

DataFinal$f_low_bmi <- ifelse(DataFinal$f_bmi<18.5,1,0)
DataFinal$f_low_bmi[is.na(DataFinal$f_bmi) | DataFinal$f_bmi>=99.90] <- NA
DataFinal$f_low_bmi[DataFinal$age>49 & !is.na(DataFinal$age)] <- NA
label(DataFinal$f_low_bmi) <- "BMI of women < 18.5"

DataFinal$temp <- ave(DataFinal$f_low_bmi, DataFinal$hh_id, FUN = function(x) max(x,na.rm=T))
DataFinal$low_bmi[DataFinal$temp== 0] <- 0
DataFinal$low_bmi[DataFinal$temp== 1] <- 1

DataFinal$hh_no_low_bmi <- ifelse(DataFinal$low_bmi==0,1,0)
    # Under this section, households take a value of '1' if no women in the household has low bmi
DataFinal$hh_no_low_bmi[is.na(DataFinal$low_bmi)] <- NA
    # Under this section, households take a value of '.' if there is no information from eligible women
DataFinal$hh_no_low_bmi[DataFinal$no_fem_eligible_bmi==1] <- 1
    # Under this section, households that don't have eligible female population are identified as non-deprived in 
    # nutrition. 
DataFinal$temp <- NULL
DataFinal$low_bmi <- NULL
label(DataFinal$hh_no_low_bmi) <- "Household has no adult with low BMI"
table(DataFinal$hh_no_low_bmi, useNA = "always")
    # Figures are exclusively based on information from eligible adult women (15-49 years)



### BMI Indicator for Men not collected 
############################################## 
DataFinal$m_bmi <- NA
label(DataFinal$m_bmi) <- "Male's BMI "

DataFinal$m_low_bmi <- NA
label(DataFinal$m_low_bmi) <- "BMI of male < 18.5"



### BMI-for-age for individuals 15-19 years and BMI for individuals 20-49 years 
##############################################
DataFinal$low_bmi_byage <- 0
label(DataFinal$low_bmi_byage) <- "Individuals with low BMI or BMI-for-age"

DataFinal$low_bmi_byage[DataFinal$f_low_bmi==1] <- 1
    # Replace variable "low_bmi_byage = 1" if eligible women have low BMI
# Note: The following command will result in 0 changes when there is no BMI information from men

DataFinal$low_bmi_byage[DataFinal$low_bmi_byage==0 & DataFinal$m_low_bmi==1] <- 1 
    # Replace variable "low_bmi_byage = 1" if eligible men have low BMI


# Note: The following command replaces BMI with BMI-for-age for those between the age group of 15-19 by their age in 
# months where information is available 

# Replacement for girls: 
DataFinal$low_bmi_byage[DataFinal$low_bmiage==1 & !is.na(DataFinal$age_month)] <- 1
DataFinal$low_bmi_byage[DataFinal$low_bmiage==0 & !is.na(DataFinal$age_month)] <- 0

# Note: The following control variable is applied when there is BMI information for women and men, as well as 
# BMI-for-age for teenagers 
DataFinal$low_bmi_byage[is.na(DataFinal$f_low_bmi) & is.na(DataFinal$low_bmiage)] <- NA
DataFinal$temp <- ave(DataFinal$low_bmi_byage, DataFinal$hh_id, FUN = function(x) max(x,na.rm=T))
DataFinal$low_bmi[DataFinal$temp==1] <- 1
DataFinal$low_bmi[DataFinal$temp==0] <- 0
DataFinal$hh_no_low_bmiage <- ifelse(DataFinal$low_bmi==0,1,0)
    # Households take a value of '1' if all eligible adults and teenagers in the household has normal bmi or 
    # bmi-for-age 

DataFinal$hh_no_low_bmiage[is.na(DataFinal$low_bmi)] <- NA
    # Households take a value of '.' if there is no information from eligible individuals in the household 

DataFinal$hh_no_low_bmiage[DataFinal$no_fem_eligible_bmi==1] <- 1 
    # Households take a value of '1' if there is no eligible population.
DataFinal$temp <- NULL
DataFinal$low_bmi <- NULL
label(DataFinal$hh_no_low_bmiage) <- "Household has no adult with low BMI or BMI-for-age"
table(DataFinal$hh_no_low_bmi[DataFinal$subsample==1], useNA = "always")	
table(DataFinal$hh_no_low_bmiage[DataFinal$subsample==1], useNA = "always")

# NOTE that hh_no_low_bmi takes value 1 if: (a) no any eligible adult in the household has (observed) low BMI or (b) 
# there are no eligible adults in the household. One has to check and adjust the dofile so all people who are eligible
# and/or measured are included. It is particularly important to check if male are measured and what age group among 
# males and females. The variable takes values 0 for those households that have at least one adult with observed low BMI.
# The variable has a missing value only when there is missing info on BMI for ALL eligible adults in the household 



########################################################################################################################
### Step 2.3b Child Nutrition 
########################################################################################################################

### Child Underweight Indicator 
############################################## 
DataFinal$temp <- ave(DataFinal$underweight, DataFinal$hh_id, FUN = function(x) max(x,na.rm=T))
DataFinal$temp_underweight[DataFinal$temp==1] <- 1
DataFinal$temp_underweight[DataFinal$temp==0] <- 0
DataFinal$hh_no_underweight <- ifelse(DataFinal$temp_underweight==0,1,0) 
    # Takes value 1 if no child in the hh is underweight 
DataFinal$hh_no_underweight[is.na(DataFinal$temp_underweight)] <- NA
DataFinal$hh_no_underweight[DataFinal$no_child_eligible==1] <- 1 
    # Households with no eligible children will receive a value of 1 
label(DataFinal$hh_no_underweight) <- "Household has no child underweight - 2 stdev"
DataFinal$temp <- NULL
DataFinal$temp_underweight <- NULL
table(DataFinal$hh_no_underweight, useNA = "always")


### Child Stunting Indicator 
############################################## 
DataFinal$temp <- ave(DataFinal$stunting, DataFinal$hh_id, FUN = function(x) max(x,na.rm=T))
DataFinal$temp_stunting[DataFinal$temp==1] <- 1
DataFinal$temp_stunting[DataFinal$temp==0] <- 0
DataFinal$hh_no_stunting <- ifelse(DataFinal$temp_stunting==0,1,0) 
    # Takes value 1 if no child in the hh is stunted
DataFinal$hh_no_stunting[is.na(DataFinal$temp_stunting)] <- NA
DataFinal$hh_no_stunting[DataFinal$no_child_eligible==1] <- 1 
label(DataFinal$hh_no_stunting) <- "Household has no child stunted - 2 stdev"
DataFinal$temp <- NULL
DataFinal$temp_stunting <- NULL
table(DataFinal$hh_no_stunting, useNA = "always")


### Child Either Stunted or Underweight Indicator 
############################################## 
DataFinal$uw_st[DataFinal$stunting==1 | DataFinal$underweight==1]  <- 1
DataFinal$uw_st[DataFinal$stunting==0 & DataFinal$underweight==0] <- 0
DataFinal$uw_st[is.na(DataFinal$stunting) & is.na(DataFinal$underweight)] <- NA
DataFinal$temp <- ave(DataFinal$uw_st, DataFinal$hh_id, FUN = function(x) max(x,na.rm=T))
DataFinal$temp_uw_st[DataFinal$temp==1] <- 1
DataFinal$temp_uw_st[DataFinal$temp==0] <- 0
DataFinal$hh_no_uw_st <- ifelse(DataFinal$temp_uw_st==0,1,0) 
    # Takes value 1 if no child in the hh is underweight or stunted
DataFinal$hh_no_uw_st[is.na(DataFinal$temp_uw_st)] <- NA
DataFinal$hh_no_uw_st[DataFinal$no_child_eligible==1] <- 1
    # Households with no eligible children will receive a value of 1 
label(DataFinal$hh_no_uw_st) <- "Household has no child underweight or stunted"
DataFinal$temp <- NULL
DataFinal$temp_uw_st <- NULL
table(DataFinal$hh_no_uw_st, useNA = "always")


########################################################################################################################
### Step 2.3c Household Nutrition Indicator 
########################################################################################################################
DataFinal$hh_nutrition_uw_st[(DataFinal$hh_no_low_bmiage==1 & DataFinal$hh_no_uw_st==1) |
                            (is.na(DataFinal$hh_no_low_bmiage) & DataFinal$hh_no_uw_st==1 & DataFinal$no_child_eligible==0) | 
                              (DataFinal$hh_no_low_bmiage==1 & is.na(DataFinal$hh_no_uw_st) & DataFinal$no_fem_eligible_bmi==0)] <- 1
DataFinal$hh_nutrition_uw_st[DataFinal$hh_no_low_bmiage==0 | DataFinal$hh_no_uw_st==0] <- 0
DataFinal$hh_nutrition_uw_st[is.na(DataFinal$hh_no_low_bmiage) & is.na(DataFinal$hh_no_uw_st)] <- NA
DataFinal$hh_nutrition_uw_st[DataFinal$no_eligibles_bmi==1] <- 1
    # If country have collected anthropometric data from women, child 0-5 & a subsample of men, we only replace households 
    # which do not have any of these three applicable population as non-deprived
label(DataFinal$hh_nutrition_uw_st) <- "Household has no child underweight/stunted or adult deprived by BMI/BMI-for-age"
table(DataFinal$hh_nutrition_uw_st, useNA = "always")


########################################################################################################################
### Step 2.4 Child Mortality 
########################################################################################################################
describe(DataFinal$v206)
describe(DataFinal$v207)
describe(DataFinal$mv206)
describe(DataFinal$mv207)
    # v206 or mv206: number of sons who have died 
    # v207 or mv207: number of daughters who have died

# Total child mortality reported by eligible women
DataFinal$temp_f <- rowSums(DataFinal[c("v206", "v207")])
DataFinal$temp_f[DataFinal$v201==0] <- 0
DataFinal$child_mortality_f <- ave(DataFinal$temp_f, DataFinal$hh_id, FUN = function(x) sum(x,na.rm=TRUE))
DataFinal$temp_miss_f <- 1
DataFinal$temp_miss_f[is.na(DataFinal$temp_f)] <- 0
DataFinal$child_mortality_temp_miss_f <- ave(DataFinal$temp_miss_f, DataFinal$hh_id, FUN = function(x) max(x,na.rm=TRUE))
DataFinal$child_mortality_f[DataFinal$child_mortality_f==0 & DataFinal$child_mortality_temp_miss_f==0 & is.na(DataFinal$temp_f) & is.na(DataFinal$v206) &  is.na(DataFinal$v207)] <- NA
label(DataFinal$child_mortality_f) <- "Occurrence of child mortality reported by women"
table(DataFinal$child_mortality_f, useNA = "always")
DataFinal$temp_f <- NULL
DataFinal$temp_miss_f <- NULL
DataFinal$child_mortality_temp_miss_f <- NULL

# Total child mortality reported by eligible men	
DataFinal$temp_m <- rowSums(DataFinal[c("mv206", "mv207")])
DataFinal$temp_m[DataFinal$mv201==0] <- 0
DataFinal$child_mortality_m <- ave(DataFinal$temp_m, DataFinal$hh_id, FUN = function(x) sum(x,na.rm=TRUE))
DataFinal$temp_miss_m <- 1
DataFinal$temp_miss_m [is.na(DataFinal$temp_m)] <- 0
DataFinal$child_mortality_temp_miss_m <- ave(DataFinal$temp_miss_m, DataFinal$hh_id, FUN = function(x) max(x,na.rm=TRUE))
DataFinal$child_mortality_m[DataFinal$child_mortality_m==0 & DataFinal$child_mortality_temp_miss_m==0 & is.na(DataFinal$temp_m) & is.na(DataFinal$mv206) &  is.na(DataFinal$mv207)] <- NA
label(DataFinal$child_mortality_m) <- "Occurrence of child mortality reported by men"
table(DataFinal$child_mortality_m, useNA = "always")
DataFinal$temp_m <- NULL
DataFinal$temp_miss_m <- NULL
DataFinal$child_mortality_temp_miss_m <- NULL

DataFinal$child_mortality <- apply(DataFinal[c("child_mortality_f", "child_mortality_m")], 1, max, na.rm=TRUE)
DataFinal$child_mortality[DataFinal$child_mortality<0] <- NA
label(DataFinal$child_mortality) <- "Total child mortality within household reported by women & men"
table(DataFinal$child_mortality[DataFinal$subsample==1], useNA = "always")	


# Deprived if any children died in the household 
##############################################
DataFinal$hh_mortality <- ifelse(DataFinal$child_mortality==0,1,0)
    # Household is replaced with a value of "1" if there is no incidence of child mortality
DataFinal$hh_mortality[is.na(DataFinal$child_mortality)] <- NA
DataFinal$hh_mortality[DataFinal$no_adults_eligible==1] <- 1
    # Change eligibility to "no_fem_eligible==1" if child mortality indicator is constructed solely using information 
    # from women 
label(DataFinal$hh_mortality) <- "Household had no child mortality"
table(DataFinal$hh_mortality[DataFinal$subsample==1], useNA = "always")


# Deprived if any children died in the household in the last 5 years from the survey year 
##############################################
table(DataFinal$child_died_per_wom_5y, useNA = "always")
    # The 'child_died_per_wom_5y' variable was constructed in Step 1.2 using information from individual women who ever 
    # gave birth in the BR file. The missing values represent eligible woman who have never ever given birth and so are
    # not present in the BR file. But these 'missing women' may be living in households where there are other women with
    # child mortality information from the BR file. So at this stage, it is important that we aggregate the information 
    # that was obtained from the BR file at the household level. Thisens ures that women who were not present in the BR 
    # file is assigned with a value, following the information provided by other women in the household

DataFinal$child_died_per_wom_5y[DataFinal$v201==0] <- 0 
    # Assign a value of "0" for:
    # - all eligible women who never ever gave birth 
DataFinal$child_died_per_wom_5y[DataFinal$no_fem_eligible==1] <- 0
    # Assign a value of "0" for:
    # - individuals living in households that have non-eligible women 	

DataFinal$temp_child_mortality_5y <- ave(DataFinal$child_died_per_wom_5y, DataFinal$hh_id, FUN = function(x) sum(x,na.rm=TRUE)) 
DataFinal$temp_child_mortality_5y_miss <- 1
DataFinal$temp_child_mortality_5y_miss[is.na(DataFinal$child_died_per_wom_5y)] <- 0
DataFinal$child_mortality_5y_miss <- ave(DataFinal$temp_child_mortality_5y_miss, DataFinal$hh_id, FUN = function(x) max(x,na.rm=TRUE))
DataFinal$temp_child_mortality_5y[DataFinal$temp_child_mortality_5y==0 & DataFinal$child_mortality_5y_miss==0] <- NA
DataFinal$child_mortality_5y <- DataFinal$temp_child_mortality_5y
DataFinal$child_mortality_5y[is.na(DataFinal$temp_child_mortality_5y) & DataFinal$child_mortality==0] <- 0
    # Replace all households as 0 death if women has missing value and men reported no death in those households

label(DataFinal$child_mortality_5y) <- "Total child mortality within household past 5 years reported by women"
table(DataFinal$child_mortality_5y[DataFinal$subsample==1], useNA = "always")

# The new standard MPI indicator takes a value of "1" if eligible women within the household reported no child mortality
# or if any child died longer than 5 years from the survey year. The indicator takes a value of "0" if women in the 
# household reported any child mortality in the last 5 years from the survey year. Households were replaced with a value
# of "1" if eligible men within the household reported no child mortality in the absence of information from women. The 
# indicator takes a missing value if there was missing information on reported death from eligible individuals.

DataFinal$hh_mortality_5y <- ifelse(DataFinal$child_mortality_5y==0,1,0)
DataFinal$hh_mortality_5y[is.na(DataFinal$child_mortality_5y)] <- NA
table(DataFinal$hh_mortality_5y[DataFinal$subsample==1], useNA = "always")	
label(DataFinal$hh_mortality_5y) <- "Household had no child mortality in the last 5 years"


########################################################################################################################
### Step 2.5 Electricity 
########################################################################################################################
# Members of the household are considered deprived if the household has no electricity 
DataFinal$electricity <- DataFinal$hv206 
describe(DataFinal$electricity)
table(DataFinal$electricity, useNA = "always")
label(DataFinal$electricity) <- "Household has electricity"


########################################################################################################################
### Step 2.6 Sanitation 
########################################################################################################################
# Members of the household are considered deprived if the household's sanitation facility is not improved, according to 
# MDG guidelines, or it is improved but shared with other household. In cases of mismatch between the MDG guideline and 
# country report, we followed the country report. 
DataFinal$toilet <- DataFinal$hv205  
describe(DataFinal$toilet)
table(DataFinal$toilet, useNA = "always") 
describe(DataFinal$hv225)
table(DataFinal$hv225, useNA = "always")  
DataFinal$shared_toilet <- DataFinal$hv225 
    # 0=no;1=yes;.=missing
DataFinal$toilet_mdg[(DataFinal$toilet==11 | DataFinal$toilet==12 | DataFinal$toilet==13 | DataFinal$toilet==21 | DataFinal$toilet==22 |
                       DataFinal$toilet==41 | DataFinal$toilet==44) & DataFinal$shared_toilet!=1] <- 1 
DataFinal$toilet_mdg[DataFinal$toilet == 14 | DataFinal$toilet ==15 | DataFinal$toilet==23 | DataFinal$toilet==31 |
                       DataFinal$toilet==42 | DataFinal$toilet==43 | DataFinal$toilet==96] <-0
DataFinal$toilet_mdg[DataFinal$shared_toilet==1] <- 0
DataFinal$toilet_mdg[is.na(DataFinal$toilet) | DataFinal$toilet==99] <- NA
label(DataFinal$toilet_mdg) <- "Household has improved sanitation with MDG Standards"
table(DataFinal$toilet, DataFinal$toilet_mdg, useNA = "always")


########################################################################################################################
### Step 2.7 Drinking Water  
########################################################################################################################
# Members of the household are considered deprived if the household does not have access to safe drinking water according
# to MDG guidelines, or safe drinking water is more than a 30-minute walk from home roundtrip. In cases of mismatch 
# between the MDG guideline and country report, we followed the country report.
DataFinal$water <- DataFinal$hv201  
DataFinal$timetowater <- DataFinal$hv204  
describe(DataFinal$water)
table(DataFinal$water, useNA = "always")	
DataFinal$ndwater <- DataFinal$hv202  
    # Non-drinking water - no observation
DataFinal$water_mdg[DataFinal$water==11 | DataFinal$water==12 | DataFinal$water==13 | DataFinal$water==14 | DataFinal$water==21 | 
                      DataFinal$water==31 | DataFinal$water==41 | DataFinal$water==51 | ((DataFinal$water==71 | DataFinal$water==72) & 
                      (DataFinal$ndwater==11 | DataFinal$ndwater==12 | DataFinal$ndwater==13 | DataFinal$ndwater==14 | DataFinal$ndwater==21 |
                         DataFinal$ndwater==31))] <- 1
DataFinal$water_mdg[DataFinal$water==32 | DataFinal$water==42 | DataFinal$water==43 | DataFinal$water==61 | DataFinal$water==62 | 
                      ((DataFinal$water==71 | DataFinal$water==72) & (DataFinal$ndwater==32 | DataFinal$ndwater==96)) | DataFinal$water==96] <- 0
DataFinal$water_mdg[(DataFinal$water_mdg==1 | is.na(DataFinal$water_mdg)) & DataFinal$timetowater >= 30 & 
                      !is.na(DataFinal$timetowater) & DataFinal$timetowater!=996 & DataFinal$timetowater!=998 & DataFinal$timetowater!=999] <- 0 
    # Deprived if water is at more than 30 minutes' walk (roundtrip) 
DataFinal$water_mdg[is.na(DataFinal$water)| DataFinal$water==99] <- NA
label(DataFinal$water_mdg) <- "Household has drinking water with MDG standards (considering distance)"
table(DataFinal$water, DataFinal$water_mdg, useNA = "always")


########################################################################################################################
### Step 2.8 Housing 
########################################################################################################################
# Members of the household are considered deprived if the household has a dirt, sand or dung floor
DataFinal$floor <- DataFinal$hv213 
describe(DataFinal$floor)
table(DataFinal$floor, useNA = "always")
DataFinal$floor_imp <- 1
DataFinal$floor_imp[DataFinal$floor==11 | DataFinal$floor==12 | DataFinal$floor==96] <- 0  
    # Deprived if "mud/earth", "sand", "dung", "other" 	
DataFinal$floor_imp[is.na(DataFinal$floor)| DataFinal$floor==99] <- NA 
label(DataFinal$floor_imp) <- "Household has floor that it is not earth/sand/dung"
table(DataFinal$floor, DataFinal$floor_imp, useNA = "always")	

# Members of the household are considered deprived if the household has wall made of natural or rudimentary materials 
DataFinal$wall <- DataFinal$hv214 
describe(DataFinal$wall)
table(DataFinal$wall, useNA = "always")	
DataFinal$wall_imp <- 1 
DataFinal$wall_imp[DataFinal$wall<=26 | DataFinal$wall==96] <- 0 
    # Deprived if "no wall" "cane/palms/trunk" "mud/dirt" "grass/reeds/thatch" "pole/bamboo with mud" "stone with mud"
    # "plywood""cardboard" "carton/plastic" "uncovered adobe" "canvas/tent" "unburnt bricks" "reused wood" "other"
DataFinal$wall_imp[is.na(DataFinal$wall) | DataFinal$wall==99] <- NA 	
label(DataFinal$wall_imp) <- "Household has wall that it is not of low quality materials"
table(DataFinal$wall, DataFinal$wall_imp, useNA = "always")	


# Members of the household are considered deprived if the household has roof made of natural or rudimentary materials 
DataFinal$roof <- DataFinal$hv215
describe(DataFinal$roof)
table(DataFinal$roof, useNA = "always")		
DataFinal$roof_imp <- 1 
DataFinal$roof_imp[DataFinal$roof<=26 | DataFinal$roof==96] <- 0 
    # Deprived if "no roof" "thatch/palm leaf" "mud/earth/lump of earth""sod/grass" "plastic/polythene sheeting" 
    # "rustic mat" "cardboard" "canvas/tent" "wood planks/reused wood" "unburnt bricks" "other"
DataFinal$roof_imp[is.na(DataFinal$roof) | DataFinal$roof==99] 	
label(DataFinal$roof_imp) <- "Household has roof that it is not of low quality materials"
table(DataFinal$roof, DataFinal$roof_imp, useNA = "always")


#*Household is deprived in housing if the roof, floor OR walls uses low quality materials.
DataFinal$housing_1 <- 1
DataFinal$housing_1[DataFinal$floor_imp==0 | DataFinal$wall_imp==0 | DataFinal$roof_imp==0] <- 0
DataFinal$housing_1[is.na(DataFinal$floor_imp) & is.na(DataFinal$wall_imp) & is.na(DataFinal$roof_imp)] <- NA
label(DataFinal$housing_1) <- "Household has roof, floor & walls that it is not low quality material"
table(DataFinal$housing_1, useNA = "always")


########################################################################################################################
### Step 2.9 Cooking Fuel 
########################################################################################################################
# Members of the household are considered deprived if the household cooks with solid fuels: wood, charcoal, crop 
# residues or dung. "Indicators for Monitoring the Millennium Development Goals", p. 63 
DataFinal$cookingfuel <- DataFinal$hv226  
describe(DataFinal$cookingfuel)
table(DataFinal$cookingfuel, useNA = "always")

DataFinal$cooking_mdg[DataFinal$cookingfuel<=5 | DataFinal$cookingfuel==95 | DataFinal$cookingfuel==96] <- 1
DataFinal$cooking_mdg[(DataFinal$cookingfuel>5 & DataFinal$cookingfuel<=11)] <- 0
DataFinal$cooking_mdg[is.na(DataFinal$cookingfuel)| DataFinal$cookingfuel==99] <- NA
label(DataFinal$cooking_mdg) <- "Househod has cooking fuel according to MDG standards"
    # DHS report page 23 
    # The report does not consider "kerosene/paraffin" as a clean source but it also does not consider it solid fuel. I 
    # follow the indicator definition that states that a household is deprived if it cooks with dung, wood, charcoal or 
    # coal; therefore "kerosene/paraffin" is considered nor deprived.
    # Non deprived if: 1 "electricity", 2 "lpg", 3 "natural gas", 4 "biogas", 5 "kerosene" , 95 "no food cooked in 
    # household", 96 "other", 12 "electricity from generator", 13 "electricity from other source", 14 "solar energy"
    # Deprived if: 6 "coal/lignite", 7 "charcoal", 8 "wood", 9 "straw/shrubs/grass" 10 "agricultural crop", 11 "animal dung"
table(DataFinal$cookingfuel, DataFinal$cooking_mdg, useNA = "always")	


########################################################################################################################
### Step 2.10 Assets ownership 
########################################################################################################################
# Members of the household are considered deprived if the household does not own more than one of: radio, TV, telephone,
# bike, motorbike or refrigerator and does not own a car or truck. 
  
# Check that for standard assets in living standards: "no"==0 and yes=="1"
describe(DataFinal$hv208)
describe(DataFinal$hv207)
describe(DataFinal$hv221)
describe(DataFinal$hv243a)
describe(DataFinal$hv209)
describe(DataFinal$hv212)
describe(DataFinal$hv210)
describe(DataFinal$hv211)
describe(DataFinal$hv243c)
describe(DataFinal$hv243e)

DataFinal$television <- DataFinal$hv208 
DataFinal$bw_television  <- NA
DataFinal$radio <- DataFinal$hv207 
DataFinal$telephone <- DataFinal$hv221 
DataFinal$mobiletelephone <- DataFinal$hv243a  
DataFinal$refrigerator <- DataFinal$hv209 
DataFinal$car <- DataFinal$hv212  	
DataFinal$bicycle <- DataFinal$hv210 
DataFinal$motorbike <- DataFinal$hv211 
DataFinal$computer <- DataFinal$hv243e
DataFinal$animal_cart <- DataFinal$hv243c


# Group telephone and mobiletelephone as a single variable
DataFinal$telephone[DataFinal$telephone==0 & DataFinal$mobiletelephone==1] <- 1
DataFinal$telephone[is.na(DataFinal$telephone) & DataFinal$mobiletelephone==1] <- NA
    
# Members of the household are considered deprived in assets if the household does not own more than one of: radio, 
# TV, telephone, bike, motorbike, refrigerator, computer or animal_cart and does not own a car or truck.
DataFinal$n_small_assets2 <- rowSums(DataFinal[c("television", "radio", "telephone", "refrigerator", "bicycle", 
                                                "motorbike", "computer", "animal_cart")])
label(DataFinal$n_small_assets2) <- "Household Number of Small Assets Owned" 
    
DataFinal$hh_assets2 <- ifelse(DataFinal$car==1 | DataFinal$n_small_assets2 > 1, 1,0) 
DataFinal$hh_assets2[is.na(DataFinal$car) & is.na(DataFinal$n_small_assets2)] <- NA
label(DataFinal$hh_assets2) <- "Household Asset Ownership: HH has car or more than 1 small assets incl computer & animal cart"
    
    
    
########################################################################################################################
### Step 2.11 Rename and keep variables for MPI calculation 
########################################################################################################################
# Retain data on sampling design: 
str(DataFinal$hv022)
str(DataFinal$hv021)	
DataFinal$strata <- DataFinal$hv022
DataFinal$psu <- DataFinal$hv021
    
    
# Retain year, month & date of interview:
str(DataFinal$hv007)
str(DataFinal$hv006)
str(DataFinal$hv008)
DataFinal$year_interview <- DataFinal$hv007 	
DataFinal$month_interview <- DataFinal$hv006 
DataFinal$date_interview <- DataFinal$hv008
    
    
### Rename key global MPI indicators for estimation 
DataFinal$d_cm <- ifelse(DataFinal$hh_mortality_5y==0,1,0)
DataFinal$d_nutr <- ifelse(DataFinal$hh_nutrition_uw_st==0,1,0)
DataFinal$d_satt <- ifelse(DataFinal$hh_child_atten==0,1,0)
DataFinal$d_educ <- ifelse(DataFinal$hh_years_edu6==0,1,0)
DataFinal$d_elct <- ifelse(DataFinal$electricity==0,1,0)
DataFinal$d_wtr <- ifelse(DataFinal$water_mdg==0,1,0)
DataFinal$d_sani <- ifelse(DataFinal$toilet_mdg==0,1,0)
DataFinal$d_hsg <- ifelse(DataFinal$housing_1==0,1,0)
DataFinal$d_ckfl <- ifelse(DataFinal$cooking_mdg ==0,1,0)
DataFinal$d_asst <- ifelse(DataFinal$hh_assets2==0,1,0)

DataFinal <- DataFinal[c("hh_id", "ind_id", "ccty", "ccnum", "cty", "survey", "year", "subsample",
                         "strata", "psu", "weight", "area", "relationship", "sex", "age", "agec7", "agec4", "marital", "hhsize",
                         "region", "year_interview", "month_interview", "date_interview", 
                         "d_cm", "d_nutr", "d_satt", "d_educ", "d_elct", "d_wtr", "d_sani", "d_hsg", "d_ckfl", "d_asst",
                         "hh_mortality_5y", "hh_nutrition_uw_st", "hh_child_atten", "hh_years_edu6", "electricity", "water_mdg",
                         "toilet_mdg", "housing_1", "cooking_mdg", "hh_assets2")] 
    
    
### Sort, compress and save data for estimation 
DataFinal[order(DataFinal$ind_id),] 
write_dta(DataFinal, (file.path(path_out, "ben_dhs18_pov.dta")))

  
    
########################################################################################################################
### MPI Calculation (TTD file)
########################################################################################################################
# SELECT COUNTRY POV FILE RUN ON LOOP FOR MORE COUNTRIES
DataTTD <- read_stata(file.path(path_in,"ben_dhs18_pov.dta"))

  
########################################################################################################################
### Define Sample Weight and total population ***
########################################################################################################################
DataTTD$sample_weight = DataTTD$weight/1000000 
    # only DHS

DataTTD$country = "Benin" 
DataTTD$countrycode = "BEN"  
    # change to weight if MICS
    

########################################################################################################################
### List of the 10 indicators included in the MPI 
########################################################################################################################
DataTTD$edu_1 <- DataTTD$hh_years_edu6
DataTTD$atten_1 <- DataTTD$hh_child_atten
DataTTD$cm_1 <- DataTTD$hh_mortality_5y
    # change countries with no child mortality 5 year to child mortality ever
DataTTD$nutri_1 <- DataTTD$hh_nutrition_uw_st
DataTTD$elec_1 <- DataTTD$electricity
DataTTD$toilet_1 <- DataTTD$toilet_mdg
DataTTD$water_1 <- DataTTD$water_mdg
DataTTD$house_1 <- DataTTD$housing_1
DataTTD$fuel_1 <- DataTTD$cooking_mdg
DataTTD$asset_1 <- DataTTD$hh_assets2
    
 
########################################################################################################################
### List of sample without missing values ***
########################################################################################################################
DataTTD$sample_1 <- ifelse(!is.na(DataTTD$edu_1) & !is.na(DataTTD$atten_1) & !is.na(DataTTD$cm_1) & 
                             !is.na(DataTTD$nutri_1) & !is.na(DataTTD$elec_1) & !is.na(DataTTD$toilet_1) & 
                             !is.na(DataTTD$water_1) & !is.na(DataTTD$house_1) & !is.na(DataTTD$fuel_1) & 
                             !is.na(DataTTD$asset_1), 1,0)

DataTTD$sample_1[DataTTD$subsample==0] <- NA
       # Note: If the anthropometric data was collected from a subsample of the total population that was sampled, 
       # then the final analysis only includes the subsample population. 
       # Percentage sample after dropping missing values 

# Survey stucture
DataTTD_weight <- svydesign(id = ~ psu,
                            strata = ~strata,
                            weights = ~sample_weight,
                            nest = T,
                            data = DataTTD)
DataTTD$per_sample_weighted_1 <- svymean(~sample_1, DataTTD_weight) 
DataTTD$per_sample_1 <-  mean(DataTTD$sample_1) 
table(DataTTD$per_sample_weighted_1, useNA = "always")
table(DataTTD$per_sample_1, useNA = "always")     


########################################################################################################################
### Define deprivation matrix 'g0' which takes values 1 if individual is deprived in the particular indicator according 
### to deprivation cutoff z as defined during step 2 ***
########################################################################################################################
DataTTD$g01_edu_1 <- ifelse(DataTTD$edu_1==1,0,1)
DataTTD$g01_atten_1 <- ifelse(DataTTD$atten_1==1,0,1)
DataTTD$g01_cm_1 <- ifelse(DataTTD$cm_1==1,0,1)
DataTTD$g01_nutri_1 <- ifelse(DataTTD$nutri_1==1,0,1)
DataTTD$g01_elec_1 <- ifelse(DataTTD$elec_1==1,0,1)
DataTTD$g01_toilet_1 <- ifelse(DataTTD$toilet_1==1,0,1)
DataTTD$g01_water_1 <- ifelse(DataTTD$water_1==1,0,1)
DataTTD$g01_house_1 <- ifelse(DataTTD$house_1==1,0,1)
DataTTD$g01_fuel_1 <- ifelse(DataTTD$fuel_1==1,0,1)
DataTTD$g01_asset_1 <- ifelse(DataTTD$asset_1==1,0,1)

# Renew survey stucture
DataTTD_weight <- svydesign(id = ~ psu,
                            strata = ~strata,
                            weights = ~sample_weight,
                            nest = T,
                            data = DataTTD)
DataTTD_weight_subset <- subset(DataTTD_weight, sample_1==1)

### Raw Headcount Ratios
DataTTD$raw1_edu_1 <- svymean(~g01_edu_1, DataTTD_weight_subset)*100
label(DataTTD$raw1_edu_1) <- "Raw Headcount: Percentage of people who are deprived in edu_1"
DataTTD$raw1_atten_1 <- svymean(~g01_atten_1, DataTTD_weight_subset)*100
label(DataTTD$raw1_atten_1) <- "Raw Headcount: Percentage of people who are deprived in atten_1"
DataTTD$raw1_cm_1 <- svymean(~g01_cm_1, DataTTD_weight_subset)*100
label(DataTTD$raw1_cm_1) <- "Raw Headcount: Percentage of people who are deprived in cm_1"
DataTTD$raw1_nutri_1 <- svymean(~g01_nutri_1, DataTTD_weight_subset)*100
label(DataTTD$raw1_nutri_1) <- "Raw Headcount: Percentage of people who are deprived in nutri_1"
DataTTD$raw1_elec_1 <- svymean(~g01_elec_1, DataTTD_weight_subset)*100
label(DataTTD$raw1_elec_1) <- "Raw Headcount: Percentage of people who are deprived in elec_1"
DataTTD$raw1_toilet_1 <- svymean(~g01_toilet_1, DataTTD_weight_subset)*100
label(DataTTD$raw1_toilet_1) <- "Raw Headcount: Percentage of people who are deprived in toilet_1"
DataTTD$raw1_water_1 <- svymean(~g01_water_1, DataTTD_weight_subset)*100
label(DataTTD$raw1_water_1) <- "Raw Headcount: Percentage of people who are deprived in water_1"
DataTTD$raw1_house_1 <- svymean(~g01_house_1, DataTTD_weight_subset)*100
label(DataTTD$raw1_house_1) <- "Raw Headcount: Percentage of people who are deprived in house_1"
DataTTD$raw1_fuel_1 <- svymean(~g01_fuel_1, DataTTD_weight_subset)*100
label(DataTTD$raw1_fuel_1) <- "Raw Headcount: Percentage of people who are deprived in fuel_1"
DataTTD$raw1_asset_1 <- svymean(~g01_asset_1, DataTTD_weight_subset)*100
label(DataTTD$raw1_asset_1) <- "Raw Headcount: Percentage of people who are deprived in asset_1"

        
########################################################################################################################
### Define vector 'w' of dimensional and indicator weight
########################################################################################################################
# If survey lacks one or more indicators, weights need to be adjusted within /each dimension such that each dimension 
# weighs 1/3 and the indicator weights add up to one (100%). CHECK COUNTRY FILE

## DIMENSION EDUCATION 
DataTTD$w1_edu_1 <- 1/6
DataTTD$w1_atten_1 <- 1/6

## DIMENSION HEALTH
DataTTD$w1_cm_1 <- 1/6
DataTTD$w1_nutri_1 <- 1/6

## DIMENSION LIVING STANDARD
DataTTD$w1_elec_1 <- 1/18
DataTTD$w1_toilet_1 <- 1/18
DataTTD$w1_water_1 <- 1/18
DataTTD$w1_house_1 <- 1/18
DataTTD$w1_fuel_1 <- 1/18
DataTTD$w1_asset_1 <- 1/18

 
########################################################################################################################
### Generate the weighted deprivation matrix 'w' * 'g0'
########################################################################################################################  
DataTTD$w1_g0_edu_1   <- ifelse(DataTTD$sample_1 ==1, DataTTD$w1_edu_1 * DataTTD$g01_edu_1, NA)
DataTTD$w1_g0_atten_1 <- ifelse(DataTTD$sample_1 ==1, DataTTD$w1_atten_1 * DataTTD$g01_atten_1, NA)
DataTTD$w1_g0_cm_1    <- ifelse(DataTTD$sample_1 ==1, DataTTD$w1_cm_1 * DataTTD$g01_cm_1, NA)
DataTTD$w1_g0_nutri_1 <- ifelse(DataTTD$sample_1 ==1, DataTTD$w1_nutri_1 * DataTTD$g01_nutri_1, NA)
DataTTD$w1_g0_elec_1  <- ifelse(DataTTD$sample_1 ==1, DataTTD$w1_elec_1 * DataTTD$g01_elec_1, NA)
DataTTD$w1_g0_toilet_1 <-ifelse(DataTTD$sample_1 ==1, DataTTD$w1_toilet_1 * DataTTD$g01_toilet_1, NA)
DataTTD$w1_g0_water_1 <- ifelse(DataTTD$sample_1 ==1, DataTTD$w1_water_1 * DataTTD$g01_water_1, NA)
DataTTD$w1_g0_house_1 <- ifelse(DataTTD$sample_1 ==1, DataTTD$w1_house_1 * DataTTD$g01_house_1, NA)
DataTTD$w1_g0_fuel_1  <- ifelse(DataTTD$sample_1 ==1, DataTTD$w1_fuel_1 * DataTTD$g01_fuel_1, NA)
DataTTD$w1_g0_asset_1 <- ifelse(DataTTD$sample_1 ==1, DataTTD$w1_asset_1 * DataTTD$g01_asset_1, NA)
    # The estimation is based only on observations that have non-missing values for all variables in varlist_pov


########################################################################################################################
### Generate the vector of individual weighted deprivation count 'c'
########################################################################################################################
DataTTD$c_vector_1 <- ifelse(DataTTD$sample_1 ==1, rowSums(DataTTD[c("w1_g0_edu_1", "w1_g0_atten_1", "w1_g0_cm_1",
                                                                      "w1_g0_nutri_1", "w1_g0_elec_1", "w1_g0_toilet_1",
                                                                      "w1_g0_water_1", "w1_g0_house_1", "w1_g0_fuel_1",
                                                                      "w1_g0_asset_1")]), NA)


########################################################################################################################
### Identification step according to poverty cutoff k (20 33 50) 
########################################################################################################################
DataTTD$multidimensionally_poor_1_20 <- ifelse(DataTTD$c_vector_1>=20/100, 1,0)
DataTTD$multidimensionally_poor_1_20[is.na(DataTTD$c_vector_1) | DataTTD$sample_1!=1] <- NA
DataTTD$multidimensionally_poor_1_33 <- ifelse(DataTTD$c_vector_1>=33/100, 1,0)
DataTTD$multidimensionally_poor_1_33[is.na(DataTTD$c_vector_1) | DataTTD$sample_1!=1] <- NA
DataTTD$multidimensionally_poor_1_50 <- ifelse(DataTTD$c_vector_1>=50/100, 1,0)
DataTTD$multidimensionally_poor_1_50[is.na(DataTTD$c_vector_1) | DataTTD$sample_1!=1] <- NA


########################################################################################################################
### Generate the censored vector of individual weighted deprivation count 'c(k)'
########################################################################################################################
DataTTD$c_censured_vector_1_20 <- ifelse(DataTTD$multidimensionally_poor_1_20==0, 0, DataTTD$c_vector_1)
DataTTD$c_censured_vector_1_33 <- ifelse(DataTTD$multidimensionally_poor_1_33==0, 0, DataTTD$c_vector_1)
DataTTD$c_censured_vector_1_50 <- ifelse(DataTTD$multidimensionally_poor_1_50==0, 0, DataTTD$c_vector_1)
      # Provide a score of zero if a person is not poor


########################################################################################################################
### Define censored deprivation matrix 'g0(k)'  with multidimensionally_poor_1_33
########################################################################################################################
DataTTD$g01_33_edu_1 <- ifelse(DataTTD$multidimensionally_poor_1_33==0, 0, 
                               ifelse(DataTTD$multidimensionally_poor_1_33!=0 & DataTTD$sample_1!=1,NA,DataTTD$g01_edu_1))
DataTTD$g01_33_atten_1 <- ifelse(DataTTD$multidimensionally_poor_1_33==0, 0, 
                               ifelse(DataTTD$multidimensionally_poor_1_33!=0 & DataTTD$sample_1!=1,NA,DataTTD$g01_atten_1))
DataTTD$g01_33_cm_1 <- ifelse(DataTTD$multidimensionally_poor_1_33==0, 0, 
                               ifelse(DataTTD$multidimensionally_poor_1_33!=0 & DataTTD$sample_1!=1,NA,DataTTD$g01_cm_1))
DataTTD$g01_33_nutri_1 <- ifelse(DataTTD$multidimensionally_poor_1_33==0, 0, 
                               ifelse(DataTTD$multidimensionally_poor_1_33!=0 & DataTTD$sample_1!=1,NA,DataTTD$g01_nutri_1))
DataTTD$g01_33_elec_1 <- ifelse(DataTTD$multidimensionally_poor_1_33==0, 0, 
                               ifelse(DataTTD$multidimensionally_poor_1_33!=0 & DataTTD$sample_1!=1,NA,DataTTD$g01_elec_1))
DataTTD$g01_33_toilet_1 <- ifelse(DataTTD$multidimensionally_poor_1_33==0, 0, 
                               ifelse(DataTTD$multidimensionally_poor_1_33!=0 & DataTTD$sample_1!=1,NA,DataTTD$g01_toilet_1))
DataTTD$g01_33_water_1 <- ifelse(DataTTD$multidimensionally_poor_1_33==0, 0, 
                               ifelse(DataTTD$multidimensionally_poor_1_33!=0 & DataTTD$sample_1!=1,NA,DataTTD$g01_water_1))
DataTTD$g01_33_house_1 <- ifelse(DataTTD$multidimensionally_poor_1_33==0, 0, 
                               ifelse(DataTTD$multidimensionally_poor_1_33!=0 & DataTTD$sample_1!=1,NA,DataTTD$g01_house_1))
DataTTD$g01_33_fuel_1 <- ifelse(DataTTD$multidimensionally_poor_1_33==0, 0, 
                                 ifelse(DataTTD$multidimensionally_poor_1_33!=0 & DataTTD$sample_1!=1,NA,DataTTD$g01_fuel_1))
DataTTD$g01_33_asset_1 <- ifelse(DataTTD$multidimensionally_poor_1_33==0, 0, 
                                 ifelse(DataTTD$multidimensionally_poor_1_33!=0 & DataTTD$sample_1!=1,NA,DataTTD$g01_asset_1))


########################################################################################################################
### Generates Multidimensional Poverty Index (MPI), Headcount (H) and Intensity of Poverty (A) 
########################################################################################################################
# Renew survey stucture
DataTTD_weight <- svydesign(id = ~ psu,
                            strata = ~strata,
                            weights = ~sample_weight,
                            nest = T,
                            data = DataTTD)
DataTTD_weight_subset <- subset(DataTTD_weight, sample_1==1)
DataTTD_weight_subset2 <- subset(DataTTD_weight, sample_1==1 & multidimensionally_poor_1_33==1)

### Multidimensional Poverty Index (MPI) 
DataTTD$MPI_1_20 <- svymean(~c_censured_vector_1_20, DataTTD_weight_subset)
label(DataTTD$MPI_1_20) <- "MPI with k=20"
DataTTD$MPI_1_33 <- svymean(~c_censured_vector_1_33, DataTTD_weight_subset)
label(DataTTD$MPI_1_33) <- "MPI with k=33"
DataTTD$MPI_1_50 <- svymean(~c_censured_vector_1_50, DataTTD_weight_subset)
label(DataTTD$MPI_1_50) <- "MPI with k=50"

DataTTD$MPI_1 <- svymean(~c_censured_vector_1_33, DataTTD_weight_subset)
label(DataTTD$MPI_1) <- "1 Multidimensional Poverty Index (MPI = H*A): Range 0 to 1"

### Headcount (H) 
DataTTD$H_1 <- svymean(~multidimensionally_poor_1_33, DataTTD_weight_subset)*100
label(DataTTD$H_1) <- "1 Headcount ratio: % Population in multidimensional poverty (H)"

### Intensity of Poverty (A) 
DataTTD$A_1 <- svymean(~c_censured_vector_1_33, DataTTD_weight_subset2)*100
label(DataTTD$A_1) <- "1 Intensity of deprivation among the poor (A): Average % of weighted deprivations"

### Population vulnerable to poverty (who experience 20-32.9% intensity of deprivations) 
DataTTD$temp <- ifelse(DataTTD$c_vector_1>=0.2 & DataTTD$c_vector_1<0.3332, 1, 
                              ifelse((DataTTD$c_vector_1<0.2 | DataTTD$c_vector_1>=0.3332) & DataTTD$sample_1!=1, NA,0))
DataTTD_weight <- svydesign(id = ~ psu,
                            strata = ~strata,
                            weights = ~sample_weight,
                            nest = T,
                            data = DataTTD)
DataTTD_weight_subset <- subset(DataTTD_weight, sample_1==1)
DataTTD$vulnerable_1 <- svymean(~temp, DataTTD_weight_subset)*100
                                  
### Population in severe poverty (with intensity 50% or higher) 
DataTTD$temp2 <- ifelse(DataTTD$c_vector_1>0.49, 1, 
                       ifelse(DataTTD$c_vector_1<=0.49 & DataTTD$sample_1!=1, NA,0))
DataTTD_weight <- svydesign(id = ~ psu,
                            strata = ~strata,
                            weights = ~sample_weight,
                            nest = T,
                            data = DataTTD)
DataTTD_weight_subset <- subset(DataTTD_weight, sample_1==1)
DataTTD$severe_1 <- svymean(~temp2, DataTTD_weight_subset)*100
label(DataTTD$severe_1) <- "1 % Population in severe poverty (with intensity 50% or higher)"

### Censored Headcount
DataTTD$cen1_edu_1 <- svymean(~g01_33_edu_1, DataTTD_weight_subset)*100
label(DataTTD$cen1_edu_1) <- "Censored Headcount: Percentage of people who are poor and deprived in edu_1)"
DataTTD$cen1_atten_1 <- svymean(~g01_33_atten_1, DataTTD_weight_subset)*100
label(DataTTD$cen1_atten_1) <- "Censored Headcount: Percentage of people who are poor and deprived in atten_1)"
DataTTD$cen1_cm_1 <- svymean(~g01_33_cm_1, DataTTD_weight_subset)*100
label(DataTTD$cen1_cm_1) <- "Censored Headcount: Percentage of people who are poor and deprived in cm_1)"
DataTTD$cen1_nutri_1 <- svymean(~g01_33_nutri_1, DataTTD_weight_subset)*100
label(DataTTD$cen1_nutri_1) <- "Censored Headcount: Percentage of people who are poor and deprived in nutri_1)"
DataTTD$cen1_elec_1 <- svymean(~g01_33_elec_1, DataTTD_weight_subset)*100
label(DataTTD$cen1_elec_1) <- "Censored Headcount: Percentage of people who are poor and deprived in elec_1)"
DataTTD$cen1_toilet_1 <- svymean(~g01_33_toilet_1, DataTTD_weight_subset)*100
label(DataTTD$cen1_toilet_1) <- "Censored Headcount: Percentage of people who are poor and deprived in toilet_1)"
DataTTD$cen1_water_1 <- svymean(~g01_33_water_1, DataTTD_weight_subset)*100
label(DataTTD$cen1_water_1) <- "Censored Headcount: Percentage of people who are poor and deprived in water_1)"
DataTTD$cen1_house_1 <- svymean(~g01_33_house_1, DataTTD_weight_subset)*100
label(DataTTD$cen1_house_1) <- "Censored Headcount: Percentage of people who are poor and deprived in house_1)"
DataTTD$cen1_fuel_1 <- svymean(~g01_33_fuel_1, DataTTD_weight_subset)*100
label(DataTTD$cen1_fuel_1) <- "Censored Headcount: Percentage of people who are poor and deprived in fuel_1)"
DataTTD$cen1_asset_1 <- svymean(~g01_33_asset_1, DataTTD_weight_subset)*100
label(DataTTD$cen1_asset_1) <- "Censored Headcount: Percentage of people who are poor and deprived in asset_1)"
   
### Dimensional Contribution
DataTTD$cont1_edu_1 <- ifelse(DataTTD$sample_1==1, DataTTD$w1_edu_1 * DataTTD$cen1_edu_1/DataTTD$MPI_1, NA)  
DataTTD$cont1_atten_1 <- ifelse(DataTTD$sample_1==1, DataTTD$w1_atten_1 * DataTTD$cen1_atten_1/DataTTD$MPI_1, NA)  
DataTTD$cont1_cm_1 <- ifelse(DataTTD$sample_1==1, DataTTD$w1_cm_1 * DataTTD$cen1_cm_1/DataTTD$MPI_1, NA)  
DataTTD$cont1_nutri_1 <- ifelse(DataTTD$sample_1==1, DataTTD$w1_nutri_1 * DataTTD$cen1_nutri_1/DataTTD$MPI_1, NA)  
DataTTD$cont1_elec_1 <- ifelse(DataTTD$sample_1==1, DataTTD$w1_elec_1 * DataTTD$cen1_elec_1/DataTTD$MPI_1, NA)  
DataTTD$cont1_toilet_1 <- ifelse(DataTTD$sample_1==1, DataTTD$w1_toilet_1 * DataTTD$cen1_toilet_1/DataTTD$MPI_1, NA)  
DataTTD$cont1_water_1 <- ifelse(DataTTD$sample_1==1, DataTTD$w1_water_1 * DataTTD$cen1_water_1/DataTTD$MPI_1, NA)  
DataTTD$cont1_house_1 <- ifelse(DataTTD$sample_1==1, DataTTD$w1_house_1 * DataTTD$cen1_house_1/DataTTD$MPI_1, NA)  
DataTTD$cont1_fuel_1 <- ifelse(DataTTD$sample_1==1, DataTTD$w1_fuel_1 * DataTTD$cen1_fuel_1/DataTTD$MPI_1, NA)  
DataTTD$cont1_asset_1 <- ifelse(DataTTD$sample_1==1, DataTTD$w1_asset_1 * DataTTD$cen1_asset_1/DataTTD$MPI_1, NA)  

### Prepare results to export 
rm("DataFinal", "DataTTD_weight", "DataTTD_weight_subset", "DataTTD_weight_subset2")
DataOutput <- DataTTD[c("MPI_1", "H_1", "A_1", "vulnerable_1", "severe_1", 
                        "cont1_nutri_1", "cont1_cm_1", "cont1_edu_1", "cont1_atten_1","cont1_fuel_1", "cont1_toilet_1", 
                        "cont1_water_1", "cont1_elec_1", "cont1_house_1", "cont1_asset_1", 
                        "per_sample_1", "per_sample_weighted_1")] 
DataOutput <- subset(DataOutput, !is.na(cont1_nutri_1))
DataOutput<- DataOutput[!duplicated(DataOutput),]

write.csv(DataOutput, file.path(path_in, "DataOutput_Benin_with_correction.csv"), row.names = T )




