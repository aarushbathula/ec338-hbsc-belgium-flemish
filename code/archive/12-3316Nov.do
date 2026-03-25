****************************************************
* Last Updated: 16 November 12:34 [FINAL CLEAN VERSION]
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

* 6. Construct sibling variables
*---------------------------------------------------

* 6.1 Sibling counts: destring + missing -> 0
foreach v of varlist brothershome1 brothershome2 sistershome1 sistershome2 {
    capture confirm variable `v'
    if !_rc {
        destring `v', replace
        replace `v' = . if inlist(`v', 9, 99)
        replace `v' = 0 if missing(`v')
    }
}
* 6.2 Total siblings and counts
capture drop siblingsum boysibs girlsibs single_sib
gen siblingsum = brothershome1 + brothershome2 + sistershome1 + sistershome2
gen boysibs    = brothershome1 + brothershome2
gen girlsibs   = sistershome1  + sistershome2
gen byte single_sib = (siblingsum == 1)

label var siblingsum "Total siblings in household(s)"
label var boysibs    "Number of brothers in household(s)"
label var girlsibs   "Number of sisters in household(s)"
label var single_sib "Exactly one sibling"

* 7. Construct outcome and treatment variables
*---------------------------------------------------

* 7.1 Reverse-coded achievement
capture drop acachieve_rev
gen acachieve_rev = 5 - acachieve if inrange(acachieve, 1, 4)
label define ac_rev 1 "Below average" 2 "Average" 3 "Good" 4 "Very good"
label values acachieve_rev ac_rev
label var acachieve_rev "Perceived academic achievement (higher = better)"

* 7.2 Same-sex sibling indicator (works for all family sizes)
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

* Verify same_sex is defined for all families with siblings
assert !missing(same_sex) if siblingsum >= 1

* 7.3 Composition variables for multi-sibling analysis
capture drop both_bro_sis boy_both_sib girl_both_sib only_same_sex

* Mixed-sibling families (both brothers and sisters)
gen byte both_bro_sis = (boysibs >= 1 & girlsibs >= 1)
label var both_bro_sis "Has both brother(s) and sister(s)"

* Child-sex-specific mixed composition
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

* Verify composition variables are mutually exclusive
gen comp_check = boy_both_sib + girl_both_sib + only_same_sex
assert comp_check <= 1 if siblingsum >= 1
drop comp_check

* 7.4 Recode agecat 1/2/3 -> 11/13/15
recode agecat (1 = 11) (2 = 13) (3 = 15), gen(agecat_new)
drop agecat
rename agecat_new agecat
label define agecat_l 11 "Age group ~11.5" 13 "Age group ~13.5" 15 "Age group ~15.5"
label values agecat agecat_l

* 8. Immigrant origin and teacher trust (2014 only)
*---------------------------------------------------

* 8.1 Immigrant origin (>= 1 parent foreign-born)
capture drop immigrant_origin
gen immigrant_origin = .

* At least one parent foreign-born (m134 or m135 between 2-6)
replace immigrant_origin = 1 if (inrange(m134, 2, 6)) | (inrange(m135, 2, 6))

* Both parents native (both == 1)
replace immigrant_origin = 0 if m134 == 1 & m135 == 1

label define imm_lab 0 "Native" 1 "Immigrant origin"
label values immigrant_origin imm_lab
label var immigrant_origin "Immigrant origin (≥1 parent foreign-born)"

* Diagnostic check
di as txt _n "Immigrant origin distribution (2014 wave):"
tab immigrant_origin if wave == 2014, missing

* 8.2 Teacher trust (2014 only, recode to 3 levels)
capture drop teacher_trust3
recode teachertust (1 2 = 1) (3 = 2) (4 5 = 3) if wave == 2014, gen(teacher_trust3)

label define tt3 1 "Low trust" 2 "Medium trust" 3 "High trust"
label values teacher_trust3 tt3
label var teacher_trust3 "Teacher trust (3-level)"

* 9. Define samples
*---------------------------------------------------

* Drop only-children (no siblings)
drop if siblingsum == 0

* Single-sibling sample (primary analysis - cleanest identification)
gen sample_main_single = (siblingsum == 1) ///
    & inlist(agecat, 11, 13, 15) ///
    & !missing(acachieve_rev, sex, same_sex, welloff)

* Full sample (all families with ≥1 sibling)
gen sample_main_full = (siblingsum >= 1) ///
    & inlist(agecat, 11, 13, 15) ///
    & !missing(acachieve_rev, sex, same_sex, welloff)

* Multi-sibling only (optional sensitivity analysis)
gen sample_multi_only = (siblingsum >= 2) ///
    & inlist(agecat, 11, 13, 15) ///
    & !missing(acachieve_rev, sex, same_sex, welloff, boy_both_sib, girl_both_sib, only_same_sex)

* Sample sizes
count if sample_main_single
di as txt "Single-sibling sample: " r(N)

count if sample_main_full
di as txt "Full sample (all siblings): " r(N)

count if sample_multi_only
di as txt "Multi-sibling only sample: " r(N)

* 10. Save final dataset
*---------------------------------------------------
save "$FINAL/hbsc_pooled_BEFL_final.dta", replace
di as result "Final dataset saved: $FINAL/hbsc_pooled_BEFL_final.dta (" _N " obs)"

*===============================================================
* 11. DESCRIPTIVE STATISTICS (POOLED WAVES)
*===============================================================

di as result _n "=== GENERATING DESCRIPTIVE STATISTICS ===" _n

* Variables to describe
local descvars acachieve_rev same_sex sex agecat wave welloff ///
               siblingsum boysibs girlsibs

* Standard esttab options
local esttab_opts "booktabs label nonumber"

* Loop over samples
foreach samp in "sample_main_single" "sample_main_full" "sample_multi_only" {
    
    if "`samp'" == "sample_main_single" local title "Single-Sibling Sample"
    if "`samp'" == "sample_main_full"   local title "All Sibling Families"
    if "`samp'" == "sample_multi_only"  local title "Multi-Sibling Sample"
    
    estpost tabstat `descvars' if `samp' [aw=weight], ///
        statistics(mean sd min max N) columns(statistics)
    
    esttab using "$TABLES/desc_`samp'.tex", replace `esttab_opts' ///
        cells("mean(fmt(3)) sd(fmt(3)) min(fmt(0)) max(fmt(0)) N(fmt(0))") ///
        title("Descriptive Statistics: `title' (Pooled Waves)") ///
        collabels("Mean" "SD" "Min" "Max" "N")
}

* Balance table: same-sex vs opposite-sex (single-sibling only)
local bal_vars sex agecat wave welloff acachieve_rev

estpost tabstat `bal_vars' if sample_main_single [aw=weight], ///
    by(same_sex) statistics(mean sd N) columns(statistics)

esttab using "$TABLES/balance_single_sib_samesex.tex", replace `esttab_opts' ///
    cells("mean(fmt(3)) sd(fmt(3)) N(fmt(0))") ///
    title("Balance Table: Same-Sex vs Opposite-Sex Sibling (Single-Sibling Sample)") ///
    mtitles("Only opposite-sex" "Has same-sex") ///
    collabels("Mean" "SD" "N")

*===============================================================
* 12. SINGLE-SIBLING ANALYSIS (POOLED WAVES)
*===============================================================

di as result _n "=== SINGLE-SIBLING MODELS (POOLED) ===" _n

local reg_opts "star(* 0.10 ** 0.05 *** 0.01) b(3) se(3)"

* 12.1 Baseline: Ordered probit + OLS
oprobit acachieve_rev same_sex i.sex i.agecat i.wave i.welloff ///
    [pw=weight] if sample_main_single, vce(cluster school)
estimates store op_pooled

regress acachieve_rev same_sex i.sex i.agecat i.wave i.welloff ///
    [pw=weight] if sample_main_single, vce(cluster school)
estimates store ols_pooled

* Balance regression: does same_sex depend on observables?
regress same_sex i.sex i.agecat i.wave i.welloff [pw=weight] if sample_main_single, vce(cluster school)

* Joint F-test of all observables
testparm i.sex i.agecat i.wave i.welloff

estpost tabstat sex agecat wave welloff ///
    if sample_main_single [aw=weight], ///
    by(same_sex) statistics(mean sd N) columns(statistics)

esttab using "$TABLES/balance_table.tex", ///
    replace booktabs label nonumber ///
    cells("mean(fmt(3)) sd(par fmt(3))") ///
    collabels("Mean" "SD") ///
    mtitles("Only opposite-sex" "Has same-sex") ///
    stats(N, fmt(0) labels("Observations")) ///
    title("Balance Table: Covariate Means by Sibling Gender (Single-Sibling Sample)") ///
    addnotes( ///
      "Means (SD in parentheses). Weighted by sample weights." ///
      "Joint F-test in regression of same_sex on sex, age, wave and affluence: F(9,191) = 0.51, p = 0.865 (clustered at school)." ///
    )

* Export main table
esttab op_pooled ols_pooled using "$TABLES/main_single_sib.tex", ///
    replace `esttab_opts' `reg_opts' ///
    keep(same_sex 1.sex 13.agecat 15.agecat 2010.wave 2014.wave ///
         2.welloff 3.welloff 4.welloff 5.welloff) ///
    title("Main Results: Same-Sex Sibling Effect (Single-Sibling Sample, Pooled Waves)") ///
    addnotes("Ordered probit (1) and OLS (2). Robust SE clustered at school level." ///
             "Sample: Children with exactly one sibling, ages 11/13/15." ///
             "Controls: child sex, age category, wave, family affluence.")

* Marginal effects (ordered probit)
oprobit acachieve_rev same_sex i.sex i.agecat i.wave i.welloff ///
    [pw=weight] if sample_main_single, vce(cluster school)
margins, dydx(same_sex) post
estimates store margins_op_pooled

esttab margins_op_pooled using "$TABLES/main_single_sib_margins.tex", ///
    replace `esttab_opts' cells(b(fmt(3)) se(par fmt(3))) ///
    title("Marginal Effects: Same-Sex Sibling (Pooled Single-Sibling Sample)") ///
    addnotes("Average marginal effects from ordered probit." ///
             "Shows change in probability of each achievement level.")

* 12.2 Heterogeneity: Age
oprobit acachieve_rev c.same_sex##i.agecat i.sex i.wave i.welloff ///
    [pw=weight] if sample_main_single, vce(cluster school)
estimates store op_age_hetsingle

margins, dydx(same_sex) at(agecat = (11 13 15)) post
estimates store margins_age_single

esttab margins_age_single using "$TABLES/main_single_sib_agehet.tex", ///
    replace `esttab_opts' cells(b(fmt(3)) se(par fmt(3))) ///
    title("Heterogeneity by Age: Same-Sex Sibling Effect (Single-Sibling)") ///
    addnotes("Marginal effects of same-sex sibling by age group.")

* 12.3 Heterogeneity: Family affluence
oprobit acachieve_rev c.same_sex##i.welloff i.sex i.agecat i.wave ///
    [pw=weight] if sample_main_single, vce(cluster school)
estimates store op_welloff_hetsingle

margins, dydx(same_sex) at(welloff = (1 2 3 4 5)) post
estimates store margins_welloff_single

esttab margins_welloff_single using "$TABLES/main_single_sib_welloffhet.tex", ///
    replace `esttab_opts' cells(b(fmt(3)) se(par fmt(3))) ///
    title("Heterogeneity by Family Affluence: Same-Sex Sibling Effect (Single-Sibling)") ///
    addnotes("Marginal effects of same-sex sibling by family affluence level.")

* 12.4 Heterogeneity: Child sex
oprobit acachieve_rev c.same_sex##i.sex i.agecat i.wave i.welloff ///
    [pw=weight] if sample_main_single, vce(cluster school)
estimates store op_sex_hetsingle

margins sex, dydx(same_sex) post
estimates store margins_sex_single

esttab margins_sex_single using "$TABLES/main_single_sib_sexhet.tex", ///
    replace `esttab_opts' cells(b(fmt(3)) se(par fmt(3))) ///
    title("Heterogeneity by Child Sex: Same-Sex Sibling Effect (Single-Sibling)") ///
    addnotes("Marginal effects of same-sex sibling separately for boys and girls.")

*===============================================================
* 13. COMPOSITION EFFECTS (Multi-Sibling, siblingsum >= 2)
*===============================================================

di as result _n "=== COMPOSITION MODELS (Multi-Sibling) ===" _n

* 13.1 Baseline composition: Ordered probit + OLS
oprobit acachieve_rev boy_both_sib girl_both_sib only_same_sex ///
    i.sex i.agecat i.wave i.welloff [pw=weight] if sample_multi_only, ///
    vce(cluster school)
estimates store op_comp_full

regress acachieve_rev boy_both_sib girl_both_sib only_same_sex ///
    i.sex i.agecat i.wave i.welloff [pw=weight] if sample_multi_only, ///
    vce(cluster school)
estimates store ols_comp_full

* Export composition table
esttab op_comp_full ols_comp_full using "$TABLES/composition_full_sample.tex", ///
    replace `esttab_opts' `reg_opts' ///
    keep(boy_both_sib girl_both_sib only_same_sex 1.sex 13.agecat 15.agecat ///
         2010.wave 2014.wave 2.welloff 3.welloff 4.welloff 5.welloff) ///
title("Sibling Composition Effects (Multi-Sibling Families, Pooled Waves)") ///
    addnotes("Sample: Children with two or more siblings (siblingsum >= 2)." ///
             "Reference group: Multi-sibling families where all siblings are opposite-sex relative to the child." ///
             "boy_both_sib: Boys with both brother(s) and sister(s)." ///
             "girl_both_sib: Girls with both brother(s) and sister(s)." ///
             "only_same_sex: All siblings same sex as the child.")

* Marginal effects (composition)
oprobit acachieve_rev boy_both_sib girl_both_sib only_same_sex ///
    i.sex i.agecat i.wave i.welloff [pw=weight] if sample_multi_only, ///
    vce(cluster school)
margins, dydx(boy_both_sib girl_both_sib only_same_sex) post
estimates store margins_comp_full

esttab margins_comp_full using "$TABLES/composition_full_margins.tex", ///
    replace `esttab_opts' cells(b(fmt(3)) se(par fmt(3))) ///
    title("Marginal Effects: Sibling Composition (Multi-Sibling Sample)") ///
    addnotes("Average marginal effects from ordered probit.")

* 13.2 Heterogeneity: Age
oprobit acachieve_rev c.boy_both_sib##i.agecat c.girl_both_sib##i.agecat ///
    c.only_same_sex i.sex i.wave i.welloff [pw=weight] ///
    if sample_multi_only, vce(cluster school)
estimates store op_comp_age

margins, dydx(boy_both_sib girl_both_sib) at(agecat = (11 13 15)) post
estimates store margins_comp_age

esttab margins_comp_age using "$TABLES/composition_agehet.tex", ///
    replace `esttab_opts' cells(b(fmt(3)) se(par fmt(3))) ///
    title("Age Heterogeneity: Sibling Composition Effects (Multi-Sibling Sample)") ///
    addnotes("Marginal effects by age group.")

* 13.3 Heterogeneity: Family affluence
oprobit acachieve_rev c.boy_both_sib##i.welloff c.girl_both_sib##i.welloff ///
    c.only_same_sex i.sex i.agecat i.wave [pw=weight] ///
    if sample_multi_only, vce(cluster school)
estimates store op_comp_welloff

margins, dydx(boy_both_sib girl_both_sib) at(welloff = (1 2 3 4 5)) post
estimates store margins_comp_welloff

esttab margins_comp_welloff using "$TABLES/composition_welloffhet.tex", ///
    replace `esttab_opts' cells(b(fmt(3)) se(par fmt(3))) ///
    title("Family Affluence Heterogeneity: Sibling Composition (Multi-Sibling Sample)") ///
    addnotes("Marginal effects by family affluence level.")

*===============================================================
* 14. 2014 WAVE ANALYSIS (IMMIGRANT ORIGIN + TEACHER TRUST)
*===============================================================

di as result _n "=== 2014 WAVE-SPECIFIC ANALYSIS ===" _n

*-----------------------------
* 14.1 Descriptive statistics (2014 only)
*-----------------------------

local desc2014 acachieve_rev same_sex immigrant_origin teacher_trust3 ///
               sex agecat welloff siblingsum boysibs girlsibs

* Single-sibling sample (2014)
estpost tabstat `desc2014' if wave==2014 & sample_main_single [aw=weight], ///
    statistics(mean sd min max N) columns(statistics)

esttab using "$TABLES/desc_2014_single_sib.tex", ///
    replace `esttab_opts' ///
    cells("mean(fmt(3)) sd(fmt(3)) min(fmt(0)) max(fmt(0)) N(fmt(0))") ///
    title("Descriptive Statistics: 2014 Single-Sibling Sample") ///
    collabels("Mean" "SD" "Min" "Max" "N")

* Full sample (2014)
estpost tabstat `desc2014' if wave==2014 & sample_main_full [aw=weight], ///
    statistics(mean sd min max N) columns(statistics)

esttab using "$TABLES/desc_2014_full_sib.tex", ///
    replace `esttab_opts' ///
    cells("mean(fmt(3)) sd(fmt(3)) min(fmt(0)) max(fmt(0)) N(fmt(0))") ///
    title("Descriptive Statistics: 2014 Full Sibling Sample") ///
    collabels("Mean" "SD" "Min" "Max" "N")

* Balance: immigrant vs native (2014 single-sibling)
local bal2014 sex agecat welloff same_sex acachieve_rev

estpost tabstat `bal2014' if wave==2014 & sample_main_single [aw=weight], ///
    by(immigrant_origin) statistics(mean sd N) columns(statistics)

esttab using "$TABLES/balance_2014_immigrant.tex", ///
    replace `esttab_opts' ///
    cells("mean(fmt(3)) sd(fmt(3)) N(fmt(0))") ///
    title("Balance Table: Immigrant Origin (2014 Single-Sibling Sample)") ///
    mtitles("Native" "Immigrant origin") ///
    collabels("Mean" "SD" "N")

*-----------------------------
* 14.2 Main 2014 regressions (single-sibling = cleanest identification)
*-----------------------------

eststo clear

* Ordered probit
eststo op_2014: oprobit acachieve_rev same_sex immigrant_origin ///
    i.sex i.agecat i.welloff ///
    [pw=weight] if wave==2014 & sample_main_single, vce(cluster school)

* OLS robustness
eststo ols_2014: regress acachieve_rev same_sex immigrant_origin ///
    i.sex i.agecat i.welloff ///
    [pw=weight] if wave==2014 & sample_main_single, vce(cluster school)

* Export table
esttab op_2014 ols_2014 using "$TABLES/2014_single_sib.tex", ///
    replace `esttab_opts' `reg_opts' ///
    keep(same_sex immigrant_origin 2.welloff 3.welloff 4.welloff 5.welloff) ///
    title("2014 Wave: Same-Sex Sibling and Immigrant Origin (Single-Sibling Sample)") ///
    addnotes("Single-sibling families only (cleanest identification)." ///
             "Immigrant origin = at least one parent foreign-born." ///
             "Controls: child sex, age category, family affluence.")

* Marginal effects
oprobit acachieve_rev same_sex immigrant_origin i.sex i.agecat i.welloff ///
    [pw=weight] if wave==2014 & sample_main_single, vce(cluster school)
margins, dydx(same_sex immigrant_origin) post

esttab using "$TABLES/2014_single_sib_margins.tex", ///
    replace `esttab_opts' cells(b(fmt(3)) se(par fmt(3))) ///
    title("Marginal Effects: 2014 Single-Sibling Sample") ///
    addnotes("Average marginal effects from ordered probit.")

*-----------------------------
* 14.3 Teacher trust heterogeneity (2014 single-sibling)
*-----------------------------

oprobit acachieve_rev c.same_sex##i.teacher_trust3 immigrant_origin ///
    i.sex i.agecat i.welloff [pw=weight] ///
    if wave==2014 & sample_main_single, vce(cluster school)
estimates store op_trust_2014

margins teacher_trust3, dydx(same_sex) post
estimates store margins_trust_2014

esttab margins_trust_2014 using "$TABLES/2014_single_sib_trust_het.tex", ///
    replace `esttab_opts' cells(b(fmt(3)) se(par fmt(3))) ///
    title("Heterogeneity by Teacher Trust: 2014 Single-Sibling Sample") ///
    addnotes("Marginal effects of same-sex sibling by level of teacher trust.")

*-----------------------------
* 14.4 ROBUSTNESS: 2014 full sample (not primary, compositional issues)
*-----------------------------

eststo clear

* Ordered probit
eststo op_2014_full: oprobit acachieve_rev same_sex immigrant_origin ///
    i.sex i.agecat i.welloff ///
    [pw=weight] if wave==2014 & sample_main_full, vce(cluster school)

* OLS
eststo ols_2014_full: regress acachieve_rev same_sex immigrant_origin ///
    i.sex i.agecat i.welloff ///
    [pw=weight] if wave==2014 & sample_main_full, vce(cluster school)

* Export
esttab op_2014_full ols_2014_full using "$TABLES/2014_fullsample.tex", ///
    replace `esttab_opts' `reg_opts' ///
    keep(same_sex immigrant_origin 2.welloff 3.welloff 4.welloff 5.welloff) ///
    title("2014 Wave: Full Sibling Sample (Robustness Check)") ///
    addnotes("Includes all families with 1+ siblings (composition endogeneity)." ///
             "Results may be biased by parental stopping rules." ///
             "Primary analysis uses single-sibling sample only.")

* Teacher trust heterogeneity (2014 full sample)
oprobit acachieve_rev c.same_sex##i.teacher_trust3 immigrant_origin ///
    i.sex i.agecat i.welloff [pw=weight] ///
    if wave==2014 & sample_main_full, vce(cluster school)

margins teacher_trust3, dydx(same_sex) post

esttab using "$TABLES/2014_fullsample_trust_het.tex", ///
    replace `esttab_opts' cells(b(fmt(3)) se(par fmt(3))) ///
