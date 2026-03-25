
****************************************************
* Last Updated: 16 November 01:15
* EC338 microeconometrics project
* Baseline effect of sibling gender on perceived achievement
****************************************************

clear all
set more off
set varabbrev off

* 0. Project paths
*---------------------------------------------------
capture confirm global PROJ
if _rc {
    global PROJ "`c(pwd)'"
}

cd "$PROJ"

global RAW    "$PROJ/data/raw"
global INT    "$PROJ/data/interim"
global FINAL  "$PROJ/data/final"
global LOGS   "$PROJ/output/logs"
global TABLES "$PROJ/output/tables"

foreach dir in INT FINAL LOGS TABLES {
    capture mkdir "$`dir'"
}

capture log close
log using "$LOGS/build.log", replace text

* 1. Parameters
*---------------------------------------------------
local COUNTRY_CODE = 56001
local f2006 "HBSC2006OAed1.0_F1.dta"
local f2010 "HBSC2010OAed1.0_F4.dta"
local f2014 "HBSC2014OAed1.1_F1.dta"

* 2. Pre-flight: confirm raw files exist
*---------------------------------------------------
foreach f in `f2006' `f2010' `f2014' {
    capture confirm file "$RAW/`f'"
    if _rc {
        di as error "Missing raw file: $RAW/`f'"
        log close
        exit 601
    }
}
di as result "All raw files present."

* 3. Housekeeping
*---------------------------------------------------
capture noisily {
    cap erase "$INT/hbsc2006_BEFL_clean.dta"
    cap erase "$INT/hbsc2010_BEFL_clean.dta"
    cap erase "$INT/hbsc2014_BEFL_clean.dta"
    cap erase "$FINAL/hbsc_pooled_BEFL_full.dta"
}

* 4. Build wave-specific datasets
*---------------------------------------------------

* 4.1 2006
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
di as txt "2006: " _N " obs"

* 4.2 2010
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
di as txt "2010: " _N " obs"

* 4.3 2014
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
di as txt "2014: " _N " obs"

* 5. Append waves and keep relevant variables
*---------------------------------------------------
use "$INT/hbsc2006_BEFL_clean.dta", clear
append using "$INT/hbsc2010_BEFL_clean.dta" "$INT/hbsc2014_BEFL_clean.dta"

levelsof wave, local(W)
assert "`W'" == "2006 2010 2014"

local famhome motherhome1 fatherhome1 stepmohome1 stepfahome1 grandmohome1 ///
              grandfahome1 fosterhome1 elsehome1 ///
              havehome2 stayhome2 motherhome2 fatherhome2 stepmohome2 ///
              stepfahome2 grandmohome2 grandfahome2 fosterhome2 elsehome2 ///
              brothershome1 brothershome2 sistershome1 sistershome2

local core age agecat school sex wave acachieve welloff m134 m135 teachertust
local tech pid weight stratum

keep `core' `famhome' `tech'
order wave school sex age agecat acachieve welloff m134 m135 `famhome' pid
di as txt "After restriction: " _N " obs"

* 7. Construct siblingsum and single_sib variables
*---------------------------------------------------

* 7.1 Sibling counts: destring + missing -> 0
foreach v of varlist brothershome1 brothershome2 sistershome1 sistershome2 {
    capture confirm variable `v'
    if !_rc {
        destring `v', replace force
        replace `v' = 0 if missing(`v')
    }
}

* 7.2 Total siblings
capture drop siblingsum
gen siblingsum = 0
foreach v of varlist brothershome1 brothershome2 sistershome1 sistershome2 {
    capture confirm variable `v'
    if !_rc replace siblingsum = siblingsum + `v'
}
label var siblingsum "Total siblings in household(s)"

* 7.3 Single sibling indicator
capture drop single_sib
gen byte single_sib = (siblingsum == 1)
label var single_sib "Exactly one sibling"

* Counts of brothers and sisters
capture drop boysibs girlsibs
gen boysibs  = brothershome1 + brothershome2
gen girlsibs = sistershome1  + sistershome2
label var boysibs  "Number of brothers in household(s)"
label var girlsibs "Number of sisters in household(s)"

* 8. Variable constructions for both samples
*---------------------------------------------------

* 8.1 Reverse-coded achievement
capture drop acachieve_rev
gen acachieve_rev = 5 - acachieve if inrange(acachieve,1,4)
label define ac_rev 1 "Below average" 2 "Average" 3 "Good" 4 "Very good"
label values acachieve_rev ac_rev
label var acachieve_rev "Perceived academic achievement (higher = better)"

* 8.2 Indicator for having at least one same-sex sibling
capture drop same_sex
gen byte same_sex = .

* Boys: same_sex = 1 if at least one brother
replace same_sex = 1 if sex == 1 & boysibs  >= 1 & siblingsum >= 1

* Girls: same_sex = 1 if at least one sister
replace same_sex = 1 if sex == 2 & girlsibs >= 1 & siblingsum >= 1

* Boys with siblings but no brothers -> only opposite-sex siblings
replace same_sex = 0 if sex == 1 & boysibs  == 0 & siblingsum >= 1

* Girls with siblings but no sisters -> only opposite-sex siblings
replace same_sex = 0 if sex == 2 & girlsibs == 0 & siblingsum >= 1

label define samesex 0 "Only opposite-sex siblings" 1 "Has same-sex sibling(s)"
label values same_sex samesex
label var same_sex "Has at least one same-sex sibling"

* 8.4 For expanded families: presence of brothers and sisters
capture drop has_brother has_sister
gen byte has_brother = (brothershome1 + brothershome2 >= 1)
gen byte has_sister  = (sistershome1  + sistershome2  >= 1)
label var has_brother "Has at least one brother"
label var has_sister  "Has at least one sister"

* 8.5 Mixed-sibling families (both brothers and sisters)
capture drop both_bro_sis
gen byte both_bro_sis = (boysibs >= 1 & girlsibs >= 1)
label var both_bro_sis "Has both brother(s) and sister(s)"

* 8.6 Child-sex-specific composition and only-same-sex indicator
capture drop boy_both_sib girl_both_sib only_same_sex

* Mixed-gender sibling sets by child sex
gen byte boy_both_sib  = (sex == 1) & (both_bro_sis == 1)
gen byte girl_both_sib = (sex == 2) & (both_bro_sis == 1)

* Only same-sex siblings (all siblings same sex as child)
gen byte only_same_sex = .

* Boys: at least one brother and no sisters
replace only_same_sex = 1 if sex == 1 & boysibs  >= 1 & girlsibs == 0 & siblingsum >= 1

* Girls: at least one sister and no brothers
replace only_same_sex = 1 if sex == 2 & girlsibs >= 1 & boysibs  == 0 & siblingsum >= 1

* Everyone else with siblings -> not only same-sex
replace only_same_sex = 0 if siblingsum >= 1 & missing(only_same_sex)

label var boy_both_sib  "Boy with both brother(s) and sister(s)"
label var girl_both_sib "Girl with both brother(s) and sister(s)"
label var only_same_sex "All siblings same sex as child"

* 8.7 Recode agecat 1/2/3 -> 11/13/15
recode agecat (1 = 11) (2 = 13) (3 = 15), gen(agecat_new)
drop agecat
rename agecat_new agecat
label define agecat_l 11 "11 years" 13 "13 years" 15 "15 years"
label values agecat agecat_l

* 9. Define main sample and subsets
*---------------------------------------------------

* Drop only-children
drop if siblingsum == 0

* Single-sibling sample (primary analysis)
gen sample_main_single = (siblingsum == 1) ///
    & inlist(agecat,11,13,15) ///
    & !missing(acachieve_rev, sex, same_sex, welloff)

* Full sample (all families with ≥1 sibling)
gen sample_main_full = (siblingsum >= 1) ///
    & inlist(agecat,11,13,15) ///
    & !missing(acachieve_rev, sex, same_sex, welloff)

* Optional sensitivity: multi-sibling only
gen sample_multi_only = (siblingsum >= 2) ///
    & inlist(agecat,11,13,15) ///
    & !missing(acachieve_rev, sex, same_sex, boy_both_sib, girl_both_sib, only_same_sex)

count if sample_main_single
di as txt "Single-sibling sample: " r(N)

count if sample_main_full
di as txt "Full sample (all siblings): " r(N)

count if sample_multi_only
di as txt "Multi-sibling only sample: " r(N)

*===============================================================
* 10. Descriptive statistics (pooled waves)
*===============================================================
di as result _n "=== DESCRIPTIVE STATISTICS: POOLED WAVES ===" _n

local descvars acachieve_rev same_sex sex agecat wave welloff ///
               siblingsum boysibs girlsibs

*-----------------------------
* 1. Single-sibling sample
*-----------------------------
estpost tabstat `descvars' if sample_main_single [aw=weight], ///
    statistics(mean sd min max N) columns(statistics)

esttab using "$TABLES/desc_single_sib.tex", replace ///
    label booktabs nonumber ///
    cells("mean(fmt(3)) sd(fmt(3)) min(fmt(0)) max(fmt(0)) N(fmt(0))") ///
    title("Descriptive Statistics: Single-Sibling Sample (Pooled Waves)") ///
    collabels("Mean" "SD" "Min" "Max" "N")

*-----------------------------
* 2. Full sibling sample (≥1 sibling)
*-----------------------------
estpost tabstat `descvars' if sample_main_full [aw=weight], ///
    statistics(mean sd min max N) columns(statistics)

esttab using "$TABLES/desc_full_sib.tex", replace ///
    label booktabs nonumber ///
    cells("mean(fmt(3)) sd(fmt(3)) min(fmt(0)) max(fmt(0)) N(fmt(0))") ///
    title("Descriptive Statistics: All Sibling Families (Pooled Waves)") ///
    collabels("Mean" "SD" "Min" "Max" "N")

*-----------------------------
* 3. Multi-sibling sample (≥2 siblings)
*-----------------------------
estpost tabstat `descvars' if sample_multi_only [aw=weight], ///
    statistics(mean sd min max N) columns(statistics)

esttab using "$TABLES/desc_multi_sib.tex", replace ///
    label booktabs nonumber ///
    cells("mean(fmt(3)) sd(fmt(3)) min(fmt(0)) max(fmt(0)) N(fmt(0))") ///
    title("Descriptive Statistics: Multi-Sibling Sample (Pooled Waves)") ///
    collabels("Mean" "SD" "Min" "Max" "N")

*-----------------------------
* 4. Balance: same-sex vs opposite-sex (single-sibling)
*-----------------------------
local bal_single sex agecat wave welloff acachieve_rev

estpost tabstat `bal_single' if sample_main_single [aw=weight], ///
    by(same_sex) statistics(mean sd N) columns(statistics)

esttab using "$TABLES/balance_single_sib_samesex.tex", replace ///
    label booktabs nonumber ///
    cells("mean(fmt(3)) sd(fmt(3)) N(fmt(0))") ///
    title("Balance Table: Same-Sex vs Opposite-Sex Sibling (Single-Sibling Sample)") ///
    mtitles("Only opposite-sex" "Has same-sex") ///
    collabels("Mean" "SD" "N")

* 11. Save final cleaned pooled dataset
*---------------------------------------------------
save "$FINAL/hbsc_pooled_BEFL_final.dta", replace
di as result "Final dataset saved: $FINAL/hbsc_pooled_BEFL_final.dta (" _N " obs)"

*===============================================================
* 12. Single-sibling models (pooled waves)
*===============================================================

* 12.1 Baseline ordered probit + margins
oprobit acachieve_rev same_sex i.sex i.agecat i.wave i.welloff ///
    [pw=weight] if sample_main_single, vce(cluster school)
estimates store op_pooled

margins, dydx(same_sex) post
estimates store margins_op_pooled

* 12.2 OLS robustness
regress acachieve_rev same_sex i.sex i.agecat i.wave i.welloff ///
    [aw=weight] if sample_main_single, vce(cluster school)
estimates store ols_pooled

* 12.3 Age heterogeneity
oprobit acachieve_rev c.same_sex##i.agecat i.sex i.wave i.welloff ///
    [pw=weight] if sample_main_single, vce(cluster school)
estimates store op_age_hetsingle

margins, dydx(same_sex) at(agecat = (11 13 15)) post
estimates store marginsopagehetsingle

* 12.4 Welloff heterogeneity
oprobit acachieve_rev c.same_sex##i.welloff i.sex i.agecat i.wave ///
    [pw=weight] if sample_main_single, vce(cluster school)
estimates store op_welloff_hetsingle

margins, dydx(same_sex) at(welloff = (1 2 3 4 5)) post
estimates store marginsopwelloffhetsingle

* 12.5 Sex heterogeneity
oprobit acachieve_rev c.same_sex##i.sex i.agecat i.wave i.welloff ///
    [pw=weight] if sample_main_single, vce(cluster school)
estimates store op_sex_hetsingle

margins sex, dydx(same_sex) post
estimates store marginsopsexdx

*-----------------------------
* EXPORT: Pooled single-sibling tables
*-----------------------------

* Main pooled results (OP + OLS)
esttab op_pooled ols_pooled using "$TABLES/main_single_sib.tex", replace ///
    booktabs label nonumber b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) ///
    keep(same_sex 1.sex 13.agecat 15.agecat 2010.wave 2014.wave ///
         2.welloff 3.welloff 4.welloff 5.welloff) ///
    title("Pooled Waves: Same-Sex Sibling (Single-Sibling Sample)") ///
    addnotes("Ordered probit and OLS. Robust SE clustered at school level.")

* Marginal effects for same_sex (pooled)
esttab margins_op_pooled using "$TABLES/main_single_sib_margins.tex", replace ///
    booktabs nonumber cells(b(fmt(3)) se(par fmt(3))) ///
    title("Marginal Effects: Pooled Single-Sibling Sample") ///
    mtitles("") 

* Age heterogeneity margins
esttab marginsopagehetsingle using "$TABLES/main_single_sib_agehet.tex", replace ///
    booktabs nonumber cells(b(fmt(3)) se(par fmt(3))) ///
    title("Heterogeneity by Age: Pooled Single-Sibling Sample") ///
    mtitles("")

* Welloff heterogeneity margins
esttab marginsopwelloffhetsingle using "$TABLES/main_single_sib_welloffhet.tex", replace ///
    booktabs nonumber cells(b(fmt(3)) se(par fmt(3))) ///
    title("Heterogeneity by Family Affluence: Pooled Single-Sibling Sample") ///
    mtitles("")

* Sex heterogeneity margins
esttab marginsopsexdx using "$TABLES/main_single_sib_sexhet.tex", replace ///
    booktabs nonumber cells(b(fmt(3)) se(par fmt(3))) ///
    title("Heterogeneity by Child Sex: Pooled Single-Sibling Sample") ///
    mtitles("")

*===============================================================
* 13. Multi-sibling models (composition effects)
*===============================================================
local compsample "if sample_multi_only"

* 13.1 Baseline composition model + margins
oprobit acachieve_rev boy_both_sib girl_both_sib only_same_sex ///
    i.sex i.agecat i.wave i.welloff [pw=weight] `compsample', ///
    vce(cluster school)
estimates store op_pooled_large

margins, dydx(boy_both_sib girl_both_sib only_same_sex) post
estimates store margins_op_pooled_large

* 13.2 OLS robustness (composition)
regress acachieve_rev boy_both_sib girl_both_sib only_same_sex ///
    i.sex i.agecat i.wave i.welloff [aw=weight] `compsample', ///
    vce(cluster school)
estimates store ols_pooled_large

* 13.3 Sex heterogeneity (multi-sibling)
oprobit acachieve_rev c.boy_both_sib##i.sex c.girl_both_sib##i.sex ///
    c.only_same_sex i.agecat i.wave i.welloff [pw=weight] ///
    `compsample', vce(cluster school)
estimates store op_sex_hetfull

margins sex, dydx(boy_both_sib girl_both_sib only_same_sex) post
estimates store marginsopsexdx_full

* 13.4 Age heterogeneity (multi-sibling)
oprobit acachieve_rev c.boy_both_sib##i.agecat c.girl_both_sib##i.agecat ///
    c.only_same_sex i.sex i.wave i.welloff [pw=weight] ///
    `compsample', vce(cluster school)
estimates store op_age_hetfull

margins, dydx(boy_both_sib girl_both_sib) at(agecat = (11 13 15)) post
estimates store marginsopagehetfull

* 13.5 Welloff heterogeneity (multi-sibling)
oprobit acachieve_rev c.boy_both_sib##i.welloff c.girl_both_sib##i.welloff ///
    c.only_same_sex i.sex i.agecat i.wave [pw=weight] ///
    `compsample', vce(cluster school)
estimates store op_welloff_hetfull

margins, dydx(boy_both_sib girl_both_sib) at(welloff = (1 2 3 4 5)) post
estimates store marginsopwelloffhetfull

*-----------------------------
* EXPORT: Composition / multi-sibling tables
*-----------------------------

* Main composition results (OP + OLS)
esttab op_pooled_large ols_pooled_large using "$TABLES/composition_multi_sib.tex", replace ///
    booktabs label nonumber b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) ///
    keep(boy_both_sib girl_both_sib only_same_sex 1.sex 13.agecat 15.agecat ///
         2010.wave 2014.wave 2.welloff 3.welloff 4.welloff 5.welloff) ///
    title("Sibling Composition: Multi-Sibling Sample") ///
    addnotes("Ordered probit and OLS. Multi-sibling families (siblingsum ≥ 2).")

* Age heterogeneity in composition effects
esttab marginsopagehetfull using "$TABLES/composition_agehet.tex", replace ///
    booktabs nonumber cells(b(fmt(3)) se(par fmt(3))) ///
    title("Age Heterogeneity: Sibling Composition Effects") ///
    mtitles("")

* Welloff heterogeneity in composition effects
esttab marginsopwelloffhetfull using "$TABLES/composition_welloffhet.tex", replace ///
    booktabs nonumber cells(b(fmt(3)) se(par fmt(3))) ///
    title("Family Affluence Heterogeneity: Sibling Composition Effects") ///
    mtitles("")

*===============================================================
* 14. 2014 wave: immigrant origin + teacher trust
*===============================================================

* 14.1 Confirm variables exist
foreach v in m134 m135 teachertust {
    capture confirm variable `v'
    if _rc {
        di as error "FATAL: missing: `v'"
        exit 111
    }
}
di as result "2014 covariates found."

* 14.2 Recode immigrant origin (>= 1 parent foreign-born)
capture drop immigrant_origin
gen immigrant_origin = .

* At least one parent foreign-born (m134 or m135 != 1)
replace immigrant_origin = 1 if (m134 >= 2 & m134 <= 6) | (m135 >= 2 & m135 <= 6)

* Both parents native (both == 1)
replace immigrant_origin = 0 if m134 == 1 & m135 == 1


label define imm_lab 0 "Native" 1 "Immigrant origin"
label values immigrant_origin imm_lab
label var immigrant_origin "Immigrant origin (≥1 parent foreign-born)"

* 14.3 Recode teacher trust (3-level, 2014 only)
capture drop teacher_trust3
recode teachertust (1 2 = 1) (3 = 2) (4 5 = 3) if wave == 2014, gen(teacher_trust3)

label define tt3 1 "Low trust" 2 "Medium trust" 3 "High trust"
label values teacher_trust3 tt3
label var teacher_trust3 "Teacher trust (3-level)"

save "$FINAL/hbsc_pooled_BEFL_final.dta", replace

*===============================================================
* DESCRIPTIVE STATISTICS: 2014 WAVE
*===============================================================

* Variables to summarise in 2014
local desc2014 acachieve_rev same_sex immigrant_origin teacher_trust3 ///
               sex agecat welloff siblingsum boysibs girlsibs

*-----------------------------
* 1. 2014 single-sibling sample
*-----------------------------
estpost tabstat `desc2014' if wave==2014 & sample_main_single [aw=weight], ///
    statistics(mean sd min max N) columns(statistics)

esttab using "$TABLES/desc_2014_single_sib.tex", replace ///
    label booktabs nonumber ///
    cells("mean(fmt(3)) sd(fmt(3)) min(fmt(0)) max(fmt(0)) N(fmt(0))") ///
    title("Descriptive Statistics: 2014 Single-Sibling Sample") ///
    collabels("Mean" "SD" "Min" "Max" "N")

*-----------------------------
* 2. 2014 full sibling sample (>=1 sibling)
*-----------------------------
estpost tabstat `desc2014' if wave==2014 & sample_main_full [aw=weight], ///
    statistics(mean sd min max N) columns(statistics)

esttab using "$TABLES/desc_2014_full_sib.tex", replace ///
    label booktabs nonumber ///
    cells("mean(fmt(3)) sd(fmt(3)) min(fmt(0)) max(fmt(0)) N(fmt(0))") ///
    title("Descriptive Statistics: 2014 Full Sibling Sample (All Families with ≥1 Sibling)") ///
    collabels("Mean" "SD" "Min" "Max" "N")

*-----------------------------
* 3. Balance: immigrant vs native (2014 single-sibling)
*-----------------------------
local bal2014 sex agecat welloff same_sex acachieve_rev

estpost tabstat `bal2014' if wave==2014 & sample_main_single [aw=weight], ///
    by(immigrant_origin) statistics(mean sd N) columns(statistics)

esttab using "$TABLES/balance_2014_immigrant.tex", replace ///
    label booktabs nonumber ///
    cells("mean(fmt(3)) sd(fmt(3)) N(fmt(0))") ///
    title("Balance Table: Immigrant Origin vs Native (2014 Single-Sibling Sample)") ///
    mtitles("Native" "Immigrant origin") ///
    collabels("Mean" "SD" "N")

*===============================================================
* 14A. MAIN CAUSAL MODEL (2014 SINGLE-SIBLING ONLY)
*===============================================================

di as result _n "=== 2014 ANALYSIS: SINGLE-SIBLING ONLY ==="

eststo clear

* Ordered probit
eststo s1: oprobit acachieve_rev same_sex immigrant_origin ///
    i.sex i.agecat i.welloff ///
    [pw=weight] if wave==2014 & sample_main_single, vce(cluster school)

* OLS robustness
eststo s2: regress acachieve_rev same_sex immigrant_origin ///
    i.sex i.agecat i.welloff ///
    [aw=weight] if wave==2014 & sample_main_single, vce(cluster school)

* Export table
esttab s1 s2 using "$TABLES/2014_single_sib.tex", replace ///
    booktabs label nonumber b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) ///
    keep(same_sex immigrant_origin 2.welloff 3.welloff 4.welloff 5.welloff) ///
    title("2014: Same-Sex Sibling + Immigrant Origin (Single-Sibling Sample)") ///
    addnotes("Single-sibling families only (cleanest identification).")

* Marginal effects
oprobit acachieve_rev same_sex immigrant_origin i.sex i.agecat i.welloff ///
    [pw=weight] if wave==2014 & sample_main_single, vce(cluster school)
margins, dydx(same_sex immigrant_origin) post

esttab using "$TABLES/2014_single_sib_margins.tex", replace ///
    booktabs nonumber cells(b(fmt(3)) se(par fmt(3))) ///
    title("Marginal Effects: 2014 Single-Sibling Sample")

*===============================================================
* 14A.2 HETEROGENEITY: TEACHER TRUST (2014 SINGLE-SIBLING)
*===============================================================

eststo clear

eststo ht1: oprobit acachieve_rev c.same_sex##i.teacher_trust3 immigrant_origin ///
    i.sex i.agecat i.welloff [pw=weight] ///
    if wave==2014 & sample_main_single, vce(cluster school)

margins teacher_trust3, dydx(same_sex) post

esttab using "$TABLES/2014_single_sib_trust_het.tex", replace ///
    booktabs nonumber ///
    cells(b(fmt(3)) se(par fmt(3))) ///
    title("Heterogeneity by Teacher Trust: 2014 Single-Sibling Sample")

*===============================================================
* 14B. ROBUSTNESS (2014 ALL SIBLINGS, siblingsum ≥1)
*===============================================================

di as result _n "=== 2014 OPTIONAL ROBUSTNESS: ALL SIBLINGS (NOT CAUSAL) ==="

eststo clear

* Ordered probit
eststo r1: oprobit acachieve_rev same_sex immigrant_origin ///
    i.sex i.agecat i.welloff ///
    [pw=weight] if wave==2014 & sample_main_full, vce(cluster school)

* OLS
eststo r2: regress acachieve_rev same_sex immigrant_origin ///
    i.sex i.agecat i.welloff ///
    [aw=weight] if wave==2014 & sample_main_full, vce(cluster school)

* Export
esttab r1 r2 using "$TABLES/2014_fullsample.tex", replace ///
    booktabs label nonumber b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) ///
    title("2014: Immigrant Origin (Full Sibling Sample — Robustness)") ///
    addnotes("Includes families with 1+ siblings (endogenous composition).")

*===============================================================
* 14B.2 Teacher Trust Heterogeneity (2014 ALL siblings)
*===============================================================

eststo clear

eststo htfull: oprobit acachieve_rev c.same_sex##i.teacher_trust3 immigrant_origin ///
    i.sex i.agecat i.welloff [pw=weight] ///
    if wave==2014 & sample_main_full, vce(cluster school)

margins teacher_trust3, dydx(same_sex) post

esttab using "$TABLES/2014_fullsample_trust_het.tex", replace ///
    booktabs nonumber cells(b(fmt(3)) se(par fmt(3))) ///
    title("Teacher Trust Heterogeneity: Full 2014 Sibling Sample (Robustness)")

log close
