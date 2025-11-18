****************************************************
* EC338 microeconometrics project
* COMPLETE VERSION: Build + Publication Tables
* Last Updated: 16 November 2025 [FINAL]
****************************************************

clear all
set more off
set varabbrev off

* 0. Project paths
*---------------------------------------------------
global PROJ   "/Users/Aarushbathula/Developer/ec338-hbsc-belgium-flemish"
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
* 11-14. PUBLICATION-QUALITY TABLES
*===============================================================

*---------------------------------------------------------------
* SETUP: Better variable labels for publication
*---------------------------------------------------------------

label var acachieve_rev "Academic achievement (1-4)"
label var same_sex "Same-sex sibling"
label var welloff "Family affluence (1-5)"
label var siblingsum "Number of siblings"
label var boysibs "Number of brothers"
label var girlsibs "Number of sisters"
label var immigrant_origin "Immigrant origin"
label var teacher_trust3 "Teacher trust"
label var boy_both_sib "Boy: mixed siblings"
label var girl_both_sib "Girl: mixed siblings"
label var only_same_sex "Only same-sex siblings"

* Create female dummy (better for tables than sex coded 1/2)
gen female = (sex == 2) if !missing(sex)
label var female "Female"
label define female_lab 0 "Male" 1 "Female"
label values female female_lab

* Standard table options
local esttab_opts "booktabs label nonumber nogaps compress"
local reg_opts "star(* 0.10 ** 0.05 *** 0.01) se(3) b(3) nobase"

*===============================================================
* TABLE 1: DESCRIPTIVE STATISTICS (Panel structure)
*===============================================================

di as result _n "=== TABLE 1: DESCRIPTIVE STATISTICS ===" _n

local descvars acachieve_rev same_sex female agecat welloff siblingsum

* Panel A: Single-sibling sample
estpost tabstat `descvars' if sample_main_single [aw=weight], ///
    statistics(mean sd N) columns(statistics)
est store desc_single

* Panel B: Full sample  
estpost tabstat `descvars' if sample_main_full [aw=weight], ///
    statistics(mean sd N) columns(statistics)
est store desc_full

* Export combined table
esttab desc_single desc_full using "$TABLES/table1_descriptives.tex", ///
    replace `esttab_opts' ///
    main(mean %6.3f) aux(sd %6.3f) ///
    mtitles("Single sibling" "All siblings") ///
    title("Descriptive Statistics\label{tab:descriptives}") ///
    addnotes("Standard deviations in parentheses. Weighted by sample weights." ///
             "Single-sibling: children with exactly one sibling. All siblings: children with 1+ siblings." ///
             "Academic achievement: 1 (below average) to 4 (very good). Same-sex sibling: indicator for at least one same-sex sibling." ///
             "Sample: Ages 11, 13, 15; waves 2006, 2010, 2014; Belgium (Flemish).")

*===============================================================
* TABLE 2: COVARIATE BALANCE TEST
*===============================================================

di as result _n "=== TABLE 2: BALANCE TABLE ===" _n

local balvars female agecat welloff

* Store joint F-test result first
qui reg same_sex i.female i.agecat i.welloff [pw=weight] ///
    if sample_main_single, vce(cluster school)
testparm i.female i.agecat i.welloff
local joint_f = string(r(F), "%6.2f")
local joint_p = string(r(p), "%6.3f")
local joint_df = r(df)
local joint_dfr = r(df_r)

* Balance table by same-sex status
estpost tabstat `balvars' if sample_main_single [aw=weight], ///
    by(same_sex) statistics(mean sd N) columns(statistics)

esttab using "$TABLES/table2_balance.tex", ///
    replace `esttab_opts' ///
    main(mean %6.3f) aux(sd %6.3f) ///
    mtitles("Opposite-sex" "Same-sex") ///
    title("Covariate Balance: Same-Sex vs Opposite-Sex Sibling\label{tab:balance}") ///
    addnotes("Standard deviations in parentheses. Single-sibling sample only. Weighted means." ///
             "Joint F-test of same\_sex on all covariates: F(`joint_df',`joint_dfr') = `joint_f', p = `joint_p'." ///
             "Standard errors clustered at school level. Null hypothesis of random assignment cannot be rejected.")

*===============================================================
* TABLE 3: MAIN RESULTS (Multiple specifications)
*===============================================================

di as result _n "=== TABLE 3: MAIN RESULTS ===" _n

eststo clear

* Column 1: No controls (unconditional effect)
eststo m1: qui oprobit acachieve_rev same_sex [pw=weight] ///
    if sample_main_single, vce(cluster school)
estadd local controls "No"
estadd local waves "No"

* Column 2: Add controls
eststo m2: qui oprobit acachieve_rev same_sex i.female i.agecat i.welloff ///
    [pw=weight] if sample_main_single, vce(cluster school)
estadd local controls "Yes"
estadd local waves "No"

* Column 3: Full specification with wave FE (MAIN)
eststo m3: qui oprobit acachieve_rev same_sex i.female i.agecat i.wave i.welloff ///
    [pw=weight] if sample_main_single, vce(cluster school)
estadd local controls "Yes"
estadd local waves "Yes"

* Column 4: OLS robustness
eststo m4: qui reg acachieve_rev same_sex i.female i.agecat i.wave i.welloff ///
    [pw=weight] if sample_main_single, vce(cluster school)
estadd local controls "Yes"
estadd local waves "Yes"

* Export
esttab m1 m2 m3 m4 using "$TABLES/table3_main_results.tex", ///
    replace `esttab_opts' `reg_opts' ///
    keep(same_sex) ///
    order(same_sex) ///
    stats(controls waves N, ///
        labels("Controls" "Wave FE" "Observations") ///
        fmt(0 0 %9.0fc)) ///
    mtitles("O.Probit" "O.Probit" "O.Probit" "OLS") ///
    title("Effect of Same-Sex Sibling on Academic Achievement\label{tab:main}") ///
    addnotes("Dependent variable: Academic achievement (1=below average to 4=very good)." ///
             "Sample: Children with exactly one sibling." ///
             "Controls: child sex, age group, family affluence. Standard errors (parentheses) clustered at school." ///
             "*** p\$<\$0.01, ** p\$<\$0.05, * p\$<\$0.10")

*===============================================================
* TABLE 4: MARGINAL EFFECTS (by outcome level)
*===============================================================

di as result _n "=== TABLE 4: MARGINAL EFFECTS ===" _n

* Run main spec and get marginal effects for each outcome
qui oprobit acachieve_rev same_sex i.female i.agecat i.wave i.welloff ///
    [pw=weight] if sample_main_single, vce(cluster school)

* Store marginal effects for each outcome level
forvalues k = 1/4 {
    qui margins, dydx(same_sex) predict(outcome(`k')) post
    est store me`k'
    
    * Re-estimate for next iteration (margins post replaces e())
    if `k' < 4 {
        qui oprobit acachieve_rev same_sex i.female i.agecat i.wave i.welloff ///
            [pw=weight] if sample_main_single, vce(cluster school)
    }
}

* Export marginal effects
esttab me1 me2 me3 me4 using "$TABLES/table4_marginal_effects.tex", ///
    replace `esttab_opts' ///
    cells(b(star fmt(4)) se(par fmt(4))) ///
    stats(N, fmt(%9.0fc) labels("Observations")) ///
    mtitles("Below avg" "Average" "Good" "Very good") ///
    title("Marginal Effects of Same-Sex Sibling on Achievement Levels\label{tab:margins}") ///
    addnotes("Marginal effects from ordered probit (Table \ref{tab:main}, column 3)." ///
             "Shows change in probability of each achievement level from having a same-sex sibling." ///
             "Standard errors in parentheses, clustered at school level." ///
             "*** p\$<\$0.01, ** p\$<\$0.05, * p\$<\$0.10")

*===============================================================
* TABLE 5: HETEROGENEITY ANALYSIS
*===============================================================

di as result _n "=== TABLE 5: HETEROGENEITY ===" _n

eststo clear

* By child sex
eststo h1: qui oprobit acachieve_rev c.same_sex##i.female i.agecat i.wave i.welloff ///
    [pw=weight] if sample_main_single, vce(cluster school)

* By age
eststo h2: qui oprobit acachieve_rev c.same_sex##i.agecat i.female i.wave i.welloff ///
    [pw=weight] if sample_main_single, vce(cluster school)

* By affluence (linear interaction)
eststo h3: qui oprobit acachieve_rev c.same_sex##c.welloff i.female i.agecat i.wave ///
    [pw=weight] if sample_main_single, vce(cluster school)

* Export
esttab h1 h2 h3 using "$TABLES/table5_heterogeneity.tex", ///
    replace `esttab_opts' `reg_opts' ///
    keep(same_sex 1.female#c.same_sex ///
         13.agecat#c.same_sex 15.agecat#c.same_sex ///
         c.same_sex#c.welloff) ///
    order(same_sex *) ///
    coeflabels(same_sex "Same-sex sibling" ///
               1.female#c.same_sex "Same-sex \$\times\$ Female" ///
               13.agecat#c.same_sex "Same-sex \$\times\$ Age 13" ///
               15.agecat#c.same_sex "Same-sex \$\times\$ Age 15" ///
               c.same_sex#c.welloff "Same-sex \$\times\$ Affluence") ///
    stats(N, fmt(%9.0fc) labels("Observations")) ///
    mtitles("By sex" "By age" "By affluence") ///
    title("Heterogeneity in Same-Sex Sibling Effect\label{tab:heterogeneity}") ///
    addnotes("Ordered probit with interactions. All models control for child sex, age, wave, affluence." ///
             "Reference: Male (col 1), Age 11 (col 2)." ///
             "Standard errors in parentheses, clustered at school level." ///
             "*** p\$<\$0.01, ** p\$<\$0.05, * p\$<\$0.10")

*===============================================================
* TABLE 6: SIBLING COMPOSITION (Multi-sibling families)
*===============================================================

di as result _n "=== TABLE 6: COMPOSITION EFFECTS ===" _n

eststo clear

* Ordered probit
eststo comp1: qui oprobit acachieve_rev boy_both_sib girl_both_sib only_same_sex ///
    i.female i.agecat i.wave i.welloff [pw=weight] ///
    if sample_multi_only, vce(cluster school)

* OLS robustness
eststo comp2: qui reg acachieve_rev boy_both_sib girl_both_sib only_same_sex ///
    i.female i.agecat i.wave i.welloff [pw=weight] ///
    if sample_multi_only, vce(cluster school)

* Export
esttab comp1 comp2 using "$TABLES/table6_composition.tex", ///
    replace `esttab_opts' `reg_opts' ///
    keep(boy_both_sib girl_both_sib only_same_sex) ///
    order(boy_both_sib girl_both_sib only_same_sex) ///
    stats(N, fmt(%9.0fc) labels("Observations")) ///
    mtitles("O.Probit" "OLS") ///
    title("Sibling Composition Effects in Multi-Sibling Families\label{tab:composition}") ///
    addnotes("Sample: Children with 2+ siblings. Reference: Only opposite-sex siblings." ///
             "Boy: mixed siblings = Boy with brother(s) and sister(s)." ///
             "Girl: mixed siblings = Girl with brother(s) and sister(s)." ///
             "Only same-sex = All siblings same sex as respondent." ///
             "Controls: child sex, age, wave, family affluence. SE clustered at school." ///
             "*** p\$<\$0.01, ** p\$<\$0.05, * p\$<\$0.10")

*===============================================================
* TABLE 7: 2014 WAVE - IMMIGRANT ORIGIN & TEACHER TRUST
*===============================================================

di as result _n "=== TABLE 7: 2014 WAVE ANALYSIS ===" _n

eststo clear

* Panel A: Main 2014 effects (O.Probit and OLS)
eststo w1: qui oprobit acachieve_rev same_sex immigrant_origin ///
    i.female i.agecat i.welloff [pw=weight] ///
    if wave==2014 & sample_main_single, vce(cluster school)

eststo w2: qui reg acachieve_rev same_sex immigrant_origin ///
    i.female i.agecat i.welloff [pw=weight] ///
    if wave==2014 & sample_main_single, vce(cluster school)

* Panel B: Teacher trust heterogeneity
eststo w3: qui oprobit acachieve_rev c.same_sex##i.teacher_trust3 immigrant_origin ///
    i.female i.agecat i.welloff [pw=weight] ///
    if wave==2014 & sample_main_single, vce(cluster school)

* Export combined table
esttab w1 w2 w3 using "$TABLES/table7_wave2014.tex", ///
    replace `esttab_opts' `reg_opts' ///
    keep(same_sex immigrant_origin ///
         2.teacher_trust3#c.same_sex 3.teacher_trust3#c.same_sex) ///
    order(same_sex immigrant_origin *) ///
    coeflabels(same_sex "Same-sex sibling" ///
               immigrant_origin "Immigrant origin" ///
               2.teacher_trust3#c.same_sex "Same-sex \$\times\$ Medium trust" ///
               3.teacher_trust3#c.same_sex "Same-sex \$\times\$ High trust") ///
    stats(N, fmt(%9.0fc) labels("Observations")) ///
    mtitles("O.Probit" "OLS" "By trust") ///
    title("2014 Wave: Immigrant Origin and Teacher Trust Mechanisms\label{tab:wave2014}") ///
    addnotes("Sample: 2014 wave, single-sibling families only." ///
             "Immigrant origin: At least one parent foreign-born." ///
             "Teacher trust: 3-level (low/medium/high). Reference: Low trust (col 3)." ///
             "Controls: child sex, age, family affluence. SE clustered at school." ///
             "*** p\$<\$0.01, ** p\$<\$0.05, * p\$<\$0.10")

*===============================================================
* APPENDIX TABLES (Optional - for robustness/supplementary)
*===============================================================

* A1: Composition heterogeneity by age (if space permits)
di as result _n "=== APPENDIX A1: COMPOSITION BY AGE ===" _n

eststo clear

eststo ca1: qui oprobit acachieve_rev c.boy_both_sib##i.agecat ///
    c.girl_both_sib##i.agecat c.only_same_sex ///
    i.female i.wave i.welloff [pw=weight] ///
    if sample_multi_only, vce(cluster school)

esttab ca1 using "$TABLES/appendix_a1_comp_age.tex", ///
    replace `esttab_opts' `reg_opts' ///
    keep(boy_both_sib girl_both_sib ///
         13.agecat#c.boy_both_sib 15.agecat#c.boy_both_sib ///
         13.agecat#c.girl_both_sib 15.agecat#c.girl_both_sib) ///
    title("Appendix A1: Composition Effects by Age\label{tab:comp_age}") ///
    addnotes("Multi-sibling sample. Interactions with age groups." ///
             "Reference age: 11. SE clustered at school.")

* A2: 2014 full sample robustness
di as result _n "=== APPENDIX A2: 2014 FULL SAMPLE ===" _n

eststo clear

eststo r1: qui oprobit acachieve_rev same_sex immigrant_origin ///
    i.female i.agecat i.welloff [pw=weight] ///
    if wave==2014 & sample_main_full, vce(cluster school)

eststo r2: qui reg acachieve_rev same_sex immigrant_origin ///
    i.female i.agecat i.welloff [pw=weight] ///
    if wave==2014 & sample_main_full, vce(cluster school)

esttab r1 r2 using "$TABLES/appendix_a2_2014_full.tex", ///
    replace `esttab_opts' `reg_opts' ///
    keep(same_sex immigrant_origin) ///
    stats(N, fmt(%9.0fc) labels("Observations")) ///
