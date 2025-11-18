*******************************************************
* 01_data_build.do – Build Harmonised Flemish HBSC Dataset
*******************************************************

version 18
clear all
set more off
set varabbrev off

* Paths inherited from master.do:
cd "$PROJ"

global RAW    "$PROJ/data/raw"
global INT    "$PROJ/data/interim"
global FINAL  "$PROJ/data/final"

foreach dir in INT FINAL {
    capture mkdir "$`dir'"
}

local COUNTRY_CODE = 56001
local f2006 "HBSC2006OAed1.0_F1.dta"
local f2010 "HBSC2010OAed1.0_F4.dta"
local f2014 "HBSC2014OAed1.1_F1.dta"

*---------------------------------------------------
* Confirm raw files exist
*---------------------------------------------------
foreach f in `f2006' `f2010' `f2014' {
    capture confirm file "$RAW/`f'"
    if _rc {
        di as error "Missing raw file: $RAW/`f'"
        exit 601
    }
}

*---------------------------------------------------
* Clean 2006
*---------------------------------------------------
use "$RAW/`f2006'", clear
gen wave = 2006
capture rename countryno     country
capture rename schoolno      school
capture rename classno       class
capture rename uniqueid      pid
capture rename sampleweights weight
capture rename subregion     stratum
keep if country == `COUNTRY_CODE'
save "$INT/hbsc2006_BEFL_clean.dta", replace

*---------------------------------------------------
* Clean 2010
*---------------------------------------------------
use "$RAW/`f2010'", clear
gen wave = 2010
capture rename countryno     country
capture rename schoolno      school
capture rename classno       class
capture rename uniqueid      pid
capture rename sampleweights weight
capture rename subregion     stratum
keep if country == `COUNTRY_CODE'
save "$INT/hbsc2010_BEFL_clean.dta", replace

*---------------------------------------------------
* Clean 2014
*---------------------------------------------------
use "$RAW/`f2014'", clear
gen wave = 2014
capture rename COUNTRYno country
capture rename id2       school
capture rename id3       class
capture rename UniqueID  pid
capture rename M137      weight
capture rename REG_NO    stratum
capture rename AGECAT    agecat
capture rename AGE       age
keep if country == `COUNTRY_CODE'
save "$INT/hbsc2014_BEFL_clean.dta", replace

*---------------------------------------------------
* Append waves
*---------------------------------------------------
use "$INT/hbsc2006_BEFL_clean.dta", clear
append using "$INT/hbsc2010_BEFL_clean.dta" "$INT/hbsc2014_BEFL_clean.dta"

*---------------------------------------------------
* Keep variables
*---------------------------------------------------
local famhome motherhome1 fatherhome1 stepmohome1 stepfahome1 grandmohome1 ///
              grandfahome1 fosterhome1 elsehome1 ///
              havehome2 stayhome2 motherhome2 fatherhome2 stepmohome2 ///
              stepfahome2 grandmohome2 grandfahome2 fosterhome2 elsehome2 ///
              brothershome1 brothershome2 sistershome1 sistershome2

local core age agecat school sex wave acachieve welloff m134 m135 teachertust
local tech pid weight stratum

keep `core' `famhome' `tech'
order wave school sex age agecat acachieve welloff m134 m135 `famhome' pid

*---------------------------------------------------
* Build sibling variables
*---------------------------------------------------
foreach v of varlist brothershome1 brothershome2 sistershome1 sistershome2 {
    destring `v', replace
    replace `v' = . if inlist(`v', 9, 99)
    replace `v' = 0 if missing(`v')
}

gen siblingsum = brothershome1 + brothershome2 + sistershome1 + sistershome2
gen boysibs    = brothershome1 + brothershome2
gen girlsibs   = sistershome1  + sistershome2
gen byte single_sib = (siblingsum == 1)

* Outcome and treatment
gen acachieve_rev = 5 - acachieve if inrange(acachieve, 1, 4)

gen byte same_sex = .
replace same_sex = 1 if sex == 1 & boysibs  >= 1 & siblingsum >= 1
replace same_sex = 1 if sex == 2 & girlsibs >= 1 & siblingsum >= 1
replace same_sex = 0 if sex == 1 & boysibs  == 0 & siblingsum >= 1
replace same_sex = 0 if sex == 2 & girlsibs == 0 & siblingsum >= 1

* Mixed composition
gen byte both_bro_sis = (boysibs >= 1 & girlsibs >= 1)
gen byte boy_both_sib  = (sex == 1) & (both_bro_sis == 1)
gen byte girl_both_sib = (sex == 2) & (both_bro_sis == 1)

gen byte only_same_sex = .
replace only_same_sex = 1 if sex == 1 & boysibs>=1 & girlsibs==0 & siblingsum>=1
replace only_same_sex = 1 if sex == 2 & girlsibs>=1 & boysibs==0 & siblingsum>=1
replace only_same_sex = 0 if siblingsum>=1 & missing(only_same_sex)

* Agecat recode
recode agecat (1=11) (2=13) (3=15), gen(agecat_new)
drop agecat
rename agecat_new agecat

* Immigrant origin
gen immigrant_origin = .
replace immigrant_origin = 1 if (inrange(m134,2,6)) | (inrange(m135,2,6))
replace immigrant_origin = 0 if m134==1 & m135==1

* Teacher trust
recode teachertust (1 2=1) (3=2) (4 5=3) if wave==2014, gen(teacher_trust3)

*---------------------------------------------------
* Sample definitions
*---------------------------------------------------
drop if siblingsum == 0

gen sample_main_single = (siblingsum == 1) ///
    & inlist(agecat,11,13,15) ///
    & !missing(acachieve_rev, sex, same_sex, welloff)

gen sample_main_full = (siblingsum >= 1) ///
    & inlist(agecat,11,13,15) ///
    & !missing(acachieve_rev, sex, same_sex, welloff)

gen sample_multi_only = (siblingsum >= 2) ///
    & inlist(agecat,11,13,15) ///
    & !missing(acachieve_rev, sex, same_sex, welloff, boy_both_sib, girl_both_sib, only_same_sex)

*---------------------------------------------------
* Save final dataset
*---------------------------------------------------
save "$FINAL/hbsc_pooled_BEFL_final.dta", replace

*******************************************************
* End 01_data_build.do
*******************************************************
