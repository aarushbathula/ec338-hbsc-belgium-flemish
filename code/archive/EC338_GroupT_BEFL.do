****************************************************
* EC338 Microeconometrics Assignment 1
* Group T - Aarush Bathula, Edward Chamberlain, Jamie Chan, Will Murphy
* Last Updated: 17 November 2025 11:31 - Aarush
****************************************************

clear all
set more off
set varabbrev off

* We use estout quite extensively for tables, so please uncomment the below line if estout is not already installed on your machine.

* ssc install estout, replace 

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
log using "$LOGS/EC338_Group_T.log", replace text

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

* Single-sibling sample (main sample for causality)
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

* Print sample sizes
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

* 11-14. Tables and analysis
*---------------------------------------------------

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
label var agecat        "Age (years, 11/13/15 groups)" 

* Create female dummy for cleaner table presentation
* (Note: Results identical to using i.sex due to re-parameterization)
capture drop female
gen female = (sex == 2) if !missing(sex)
label var female "Female"
label define female_lab 0 "Male" 1 "Female"
label values female female_lab

* Standard table options
local esttab_opts "booktabs label nonumber nogaps compress"
local reg_opts "star(* 0.10 ** 0.05 *** 0.01) se(3) b(3) nobase"

* Table 1 - Descriptive Stats (2 Panels)
*---------------------------------------------------
di as result _n "=== TABLE 1: DESCRIPTIVE STATISTICS (PANELS A & B) ===" _n

* Variables to show in descriptives
* (Outcome, treatment, key predetermined controls)
local descvars acachieve_rev same_sex female agecat welloff ///
               motherhome1 fatherhome1 siblingsum
 
count if sample_main_full
local N_full = r(N)

count if sample_main_single
local N_single = r(N)

count if sample_main_full & siblingsum >= 2
local N_multi  = r(N)

di as txt "Full analysis sample (siblings >=1): " `N_full'
di as txt "  of which single-sibling:          " `N_single'
di as txt "           multi-sibling (>=2):      " `N_multi'
di as txt "Check N_single + N_multi = " `N_single' + `N_multi'


di as result _n "=== TABLE 1: DESCRIPTIVE STATISTICS (HORIZONTAL PANELS + COMPOSITION) ===" _n

* 0. Variables to show (labels already set above)
local descvars acachieve_rev same_sex female agecat welloff ///
               motherhome1 fatherhome1 siblingsum

* 1. Ns for Panel A (single-sibling)
count if sample_main_single
local N1_tot = r(N)
count if sample_main_single & same_sex == 1
local N1_ss  = r(N)
count if sample_main_single & same_sex == 0
local N1_os  = r(N)

* 2. Composition flags for multi-sibling sample
*    (only_same_sex already defined earlier)
capture drop mixed
gen byte mixed = (boy_both_sib == 1 | girl_both_sib == 1) if sample_multi_only

* Only opposite-sex siblings in multi-sibling sample:
* no same-sex sibs and not mixed
capture drop only_opp
gen byte only_opp = (same_sex == 0 & mixed == 0) if sample_multi_only

* 3. Ns for Panel B (multi-sibling composition)
count if sample_multi_only
local N2_tot = r(N)
count if sample_multi_only & only_same_sex == 1
local N2_ss  = r(N)
count if sample_multi_only & mixed == 1
local N2_mix = r(N)
count if sample_multi_only & only_opp == 1
local N2_os  = r(N)

di as txt "Panel A (single-sibling) N = " `N1_tot'
di as txt "Panel B (multi-sibling, composition) N = " `N2_tot'

* 4. Open LaTeX file for writing
file close _all
file open t1 using "$TABLES/table1_grouped.tex", write replace text

* 5. LaTeX header: Panel A (3 cols) + Panel B (4 cols)
file write t1 ///
"\begin{tabular}{l*{7}{c}} \toprule" _n ///
" & \multicolumn{3}{c}{Panel A. One-sibling sample} &" ///
"   \multicolumn{4}{c}{Panel B. Multi-sibling sample (composition)} \\" _n ///
"\cmidrule(lr){2-4} \cmidrule(lr){5-8}" _n ///
" & Total & Same-sex & Opposite-sex & Total & Only same-sex & Mixed siblings & Only opposite-sex \\" _n ///
"\midrule" _n

* 6. Loop over variables and write mean (sd) cells
foreach v of local descvars {

    * Variable label (fallback to name)
    local vlab : variable label `v'
    if "`vlab'" == "" local vlab "`v'"
    * Escape underscores for LaTeX
    local vlab = subinstr("`vlab'","_","\_",.)

    * -------- Panel A: one-sibling --------
    quietly summarize `v' if sample_main_single [aw=weight]
    local A_tot = "`=string(r(mean),"%4.2f")' (`=string(r(sd),"%4.2f")')"

    quietly summarize `v' if sample_main_single & same_sex == 1 [aw=weight]
    local A_ss  = "`=string(r(mean),"%4.2f")' (`=string(r(sd),"%4.2f")')"

    quietly summarize `v' if sample_main_single & same_sex == 0 [aw=weight]
    local A_os  = "`=string(r(mean),"%4.2f")' (`=string(r(sd),"%4.2f")')"

    * -------- Panel B: multi-sibling composition --------
    quietly summarize `v' if sample_multi_only [aw=weight]
    local B_tot = "`=string(r(mean),"%4.2f")' (`=string(r(sd),"%4.2f")')"

    quietly summarize `v' if sample_multi_only & only_same_sex == 1 [aw=weight]
    local B_ss  = "`=string(r(mean),"%4.2f")' (`=string(r(sd),"%4.2f")')"

    quietly summarize `v' if sample_multi_only & mixed == 1 [aw=weight]
    local B_mix = "`=string(r(mean),"%4.2f")' (`=string(r(sd),"%4.2f")')"

    quietly summarize `v' if sample_multi_only & only_opp == 1 [aw=weight]
    local B_os  = "`=string(r(mean),"%4.2f")' (`=string(r(sd),"%4.2f")')"

    * Write one row
    file write t1 ///
    "`vlab' & `A_tot' & `A_ss' & `A_os' & `B_tot' & `B_ss' & `B_mix' & `B_os' \\" _n
}

* 7. Observations row and closing
file write t1 "\midrule" _n ///
"Observations & `N1_tot' & `N1_ss' & `N1_os' & `N2_tot' & `N2_ss' & `N2_mix' & `N2_os' \\" _n ///
"\bottomrule" _n ///
"\end{tabular}" _n

file close t1
	

* Table 2: Covariates Balance Test
**---------------------------------------------------


quietly regress same_sex female i.agecat i.wave i.welloff ///
    if sample_main_single, vce(cluster school)

* Joint F-test of all predetermined covariates
testparm female i.agecat i.wave i.welloff

local joint_f   = string(r(F),    "%6.2f")
local joint_p   = string(r(p),    "%6.3f")
local joint_df  = r(df)
local joint_dfr = r(df_r)

count if sample_main_single
local N_total = r(N)

count if sample_main_single & same_sex == 1
local N_ss = r(N)

count if sample_main_single & same_sex == 0
local N_os = r(N)

* Predetermined controls used in baseline regression / balance table
* (add/remove variables here if your baseline spec has more/less)
local balvars female age welloff motherhome1 fatherhome1

* t-tests of equality of means, by same_sex (0 = opp-sex, 1 = same-sex)
eststo clear
estpost ttest `balvars' if sample_main_single, by(same_sex)


esttab using "$TABLES/table2_balance.tex", replace ///
    cells("mu_2(fmt(2)) mu_1(fmt(2)) b(fmt(2)) se(par fmt(2))") ///
    collabels("Same-sex (N=`N_ss')" "Opposite-sex (N=`N_os')" "Difference") ///
    label nonumber noobs nomtitles ///
    title("Baseline Characteristics by Sibling Gender\label{tab:balance}") ///
    addnotes( ///
    "Sample restricted to children with exactly one sibling in the Flemish Belgium HBSC (2006, 2010, 2014); total estimation sample size is N=`N_total'." ///
    "Entries are means for the same-sex sibling group (column 1) and the opposite-sex sibling group (column 2). Column 3 reports the difference in means (same-sex minus opposite-sex) with standard errors in parentheses." ///
    "Variables: female = 1 if the respondent is female; age = respondent's age in years; welloff = Family Affluence Scale (higher values indicate higher family socioeconomic status); motherhome1 = 1 if the mother lives in the same home; fatherhome1 = 1 if the father lives in the same home." ///
    "The covariates reported in this table correspond to the predetermined controls included in the baseline regression specification." ///
    "Joint test of covariate balance from regression of same\_sex on all covariates: F(`joint_df',`joint_dfr') = `joint_f'; p-value = `joint_p'." )

	
* Table 3: Main Results	
*---------------------------------------------------

di as result _n "=== TABLE 3: MAIN RESULTS ===" _n
eststo clear

* Col 1: Oprobit (no controls)
eststo m1: qui oprobit acachieve_rev same_sex ///
    [pw=weight] if sample_main_single, vce(cluster school)
capture estadd scalar ll   = e(ll)
capture estadd scalar r2_p = e(r2_p)

* Col 2: Oprobit (controls)
eststo m2: qui oprobit acachieve_rev same_sex i.female i.agecat i.welloff ///
    [pw=weight] if sample_main_single, vce(cluster school)
capture estadd scalar ll   = e(ll)
capture estadd scalar r2_p = e(r2_p)

* Col 3: Oprobit (controls + wave FE) — preferred spec
eststo m3: qui oprobit acachieve_rev same_sex i.female i.agecat i.wave i.welloff ///
    [pw=weight] if sample_main_single, vce(cluster school)
capture estadd scalar ll   = e(ll)
capture estadd scalar r2_p = e(r2_p)

* Col 4: OLS
eststo m4: qui reg acachieve_rev same_sex i.female i.agecat i.wave i.welloff ///
    [pw=weight] if sample_main_single, vce(cluster school)
capture estadd scalar r2 = e(r2)

esttab m1 m2 m3 m4 using "$TABLES/table3_main_results.tex", ///
    replace `esttab_opts' `reg_opts' ///
    keep(same_sex) ///
    order(same_sex) ///
    stats(N ll r2_p r2, ///
          labels("Observations" "Log likelihood" "Pseudo R^2" "R^2") ///
          fmt(%9.0fc %9.3f %9.3f %9.3f)) ///
    mtitles("O.Probit" "O.Probit" "O.Probit" "OLS") ///
    title("Effect of Same-Sex Sibling on Academic Achievement\label{tab:main}") ///
    addnotes("Columns (1)--(3): ordered probit coefficients; column (4): OLS coefficients." ///
             "Dependent variable: academic achievement (1=below average, 4=very good)." ///
             "Sample: children with exactly one sibling, ages 11/13/15, Flemish Belgium." ///
             "Controls: female, age group, family affluence; wave fixed effects in columns (3) and (4)." ///
             "All models use survey weights and cluster standard errors at the school level.")
			 
* Table 4: Marginal Effects
*===============================================================

di as result _n "=== TABLE 4: MARGINAL EFFECTS ===" _n
eststo clear

qui oprobit acachieve_rev same_sex i.female i.agecat i.wave i.welloff ///
    [pw=weight] if sample_main_single, vce(cluster school)

forvalues k = 1/4 {
    margins, dydx(same_sex) predict(outcome(`k')) post
    eststo me`k'
    if `k' < 4 {
        qui oprobit acachieve_rev same_sex i.female i.agecat i.wave i.welloff ///
            [pw=weight] if sample_main_single, vce(cluster school)
    }
}

esttab me1 me2 me3 me4 using "$TABLES/table4_marginal_effects.tex", ///
    replace `esttab_opts' ///
    cells(b(star fmt(4)) se(par fmt(4))) ///
    stats(N, fmt(%9.0fc) labels("Observations")) ///
    mtitles("Below avg" "Average" "Good" "Very good") ///
    title("Marginal Effects of Same-Sex Sibling on Achievement Levels\label{tab:margins}") ///
    addnotes("Marginal effects from ordered probit (Table \ref{tab:main}, column 3)." ///
             "Shows change in probability of each achievement level from having a same-sex sibling." ///
             "Standard errors in parentheses, clustered at school level.")

* Table 5: Heterogeneity Analysis
*---------------------------------------------------
di as result _n "=== TABLE 5: HETEROGENEITY ===" _n
eststo clear

* By sex
eststo h1: qui oprobit acachieve_rev c.same_sex##i.female ///
    i.agecat i.wave i.welloff [pw=weight] if sample_main_single, vce(cluster school)
capture estadd scalar ll   = e(ll)
capture estadd scalar r2_p = e(r2_p)

* By age
eststo h2: qui oprobit acachieve_rev c.same_sex##i.agecat ///
    i.female i.wave i.welloff [pw=weight] if sample_main_single, vce(cluster school)
capture estadd scalar ll   = e(ll)
capture estadd scalar r2_p = e(r2_p)

* By affluence (linear interaction)
eststo h3: qui oprobit acachieve_rev c.same_sex##c.welloff ///
    i.female i.agecat i.wave [pw=weight] if sample_main_single, vce(cluster school)
capture estadd scalar ll   = e(ll)
capture estadd scalar r2_p = e(r2_p)

esttab h1 h2 h3 using "$TABLES/table5_heterogeneity.tex", ///
    replace `esttab_opts' `reg_opts' ///
    keep(same_sex 1.female#c.same_sex ///
         13.agecat#c.same_sex 15.agecat#c.same_sex ///
         c.same_sex#c.welloff) ///
    order(same_sex *) ///
    coeflabels(same_sex "Same-sex sibling" ///
               1.female#c.same_sex "Same-sex × Female" ///
               13.agecat#c.same_sex "Same-sex × Age 13" ///
               15.agecat#c.same_sex "Same-sex × Age 15" ///
               c.same_sex#c.welloff "Same-sex × Affluence") ///
    stats(N ll r2_p, fmt(%9.0fc %9.3f %9.3f) ///
          labels("Observations" "Log likelihood" "Pseudo R^2")) ///
    mtitles("By sex" "By age" "By affluence") ///
    title("Heterogeneity in Same-Sex Sibling Effect\label{tab:heterogeneity}") ///
    addnotes("Ordered probit with interactions. All models control for child sex, age, wave, and affluence." ///
             "Reference: Male (col 1), Age 11 (col 2). Column (3) uses linear interaction in affluence." ///
             "Standard errors in parentheses, clustered at school level.")
			 
* Table 6: Multi-Sibling Composition
*---------------------------------------------------

di as result _n "=== TABLE 6: COMPOSITION EFFECTS ===" _n
eststo clear

eststo comp1: qui oprobit acachieve_rev boy_both_sib girl_both_sib only_same_sex ///
    i.female i.agecat i.wave i.welloff [pw=weight] if sample_multi_only, vce(cluster school)
capture estadd scalar ll   = e(ll)
capture estadd scalar r2_p = e(r2_p)

eststo comp2: qui reg acachieve_rev boy_both_sib girl_both_sib only_same_sex ///
    i.female i.agecat i.wave i.welloff [pw=weight] if sample_multi_only, vce(cluster school)
capture estadd scalar r2 = e(r2)

esttab comp1 comp2 using "$TABLES/table6_composition.tex", ///
    replace `esttab_opts' `reg_opts' ///
    keep(boy_both_sib girl_both_sib only_same_sex) ///
    order(boy_both_sib girl_both_sib only_same_sex) ///
    stats(N ll r2_p r2, fmt(%9.0fc %9.3f %9.3f %9.3f) ///
          labels("Observations" "Log likelihood" "Pseudo R^2" "R^2")) ///
    mtitles("O.Probit" "OLS") ///
    title("Sibling Composition Effects in Multi-Sibling Families\label{tab:composition}") ///
    addnotes("Sample: children with 2+ siblings. Reference: only opposite-sex siblings." ///
             "Boy: mixed = boy with brother(s) and sister(s). Girl: mixed = girl with brother(s) and sister(s)." ///
             "Only same-sex = all siblings same sex as respondent." ///
             "Controls: child sex, age group, wave, family affluence. SE clustered at school level.")
			 

* Table 7: 2014 Wave - Control & Heterogeneity
*---------------------------------------------------

di as result _n "=== TABLE 7: 2014 MECHANISMS ===" _n
eststo clear

eststo w1: qui oprobit acachieve_rev same_sex immigrant_origin ///
    i.female i.agecat i.welloff [pw=weight] ///
    if wave==2014 & sample_main_single, vce(cluster school)
capture estadd scalar ll   = e(ll)
capture estadd scalar r2_p = e(r2_p)

eststo w2: qui reg acachieve_rev same_sex immigrant_origin ///
    i.female i.agecat i.welloff [pw=weight] ///
    if wave==2014 & sample_main_single, vce(cluster school)
capture estadd scalar r2 = e(r2)

eststo w3: qui oprobit acachieve_rev c.same_sex##i.teacher_trust3 immigrant_origin ///
    i.female i.agecat i.welloff [pw=weight] ///
    if wave==2014 & sample_main_single, vce(cluster school)
capture estadd scalar ll   = e(ll)
capture estadd scalar r2_p = e(r2_p)

esttab w1 w2 w3 using "$TABLES/table7_wave2014.tex", ///
    replace `esttab_opts' `reg_opts' ///
    keep(same_sex immigrant_origin ///
         2.teacher_trust3#c.same_sex 3.teacher_trust3#c.same_sex) ///
    order(same_sex immigrant_origin *) ///
    coeflabels(same_sex "Same-sex sibling" ///
               immigrant_origin "Immigrant origin" ///
               2.teacher_trust3#c.same_sex "Same-sex × Medium trust" ///
               3.teacher_trust3#c.same_sex "Same-sex × High trust") ///
    stats(N ll r2_p r2, fmt(%9.0fc %9.3f %9.3f %9.3f) ///
          labels("Observations" "Log likelihood" "Pseudo R^2" "R^2")) ///
    mtitles("O.Probit" "OLS" "By trust") ///
    title("2014 Wave: Immigrant Origin and Teacher Trust Mechanisms\label{tab:wave2014}") ///
    addnotes("Sample: 2014 wave, single-sibling families only." ///
             "Immigrant origin: at least one parent foreign-born. Teacher trust: 3-level (low, medium, high; ref: low)." ///
             "Controls: child sex, age, family affluence. SE clustered at school level.")
			 

* Table 8: Composition By Age
*---------------------------------------------------

di as result _n "=== COMPOSITION BY AGE ===" _n
eststo clear

* Run model and STORE it as ca1
eststo ca1: qui oprobit acachieve_rev c.boy_both_sib##i.agecat ///
    c.girl_both_sib##i.agecat only_same_sex ///
    i.female i.wave i.welloff [pw=weight] if sample_multi_only, vce(cluster school)

* Add fit stats safely
capture estadd scalar ll   = e(ll)
capture estadd scalar r2_p = e(r2_p)

* Now export
esttab ca1 using "$TABLES/table8_comp_age.tex", ///
    replace `esttab_opts' `reg_opts' ///
    keep(boy_both_sib girl_both_sib ///
         13.agecat#c.boy_both_sib 15.agecat#c.boy_both_sib ///
         13.agecat#c.girl_both_sib 15.agecat#c.girl_both_sib only_same_sex) ///
    order(boy_both_sib girl_both_sib *) ///
    stats(N ll r2_p, fmt(%9.0fc %9.3f %9.3f) ///
          labels("Observations" "Log likelihood" "Pseudo R^2")) ///
    title("Composition Effects by Age\label{tab:comp_age}") ///
    addnotes("Multi-sibling sample. Interactions with age groups. Reference age: 11." ///
             "Standard errors clustered at school level.")	 

			 
* Table 9: 2014 Full Samnple Robustness
*---------------------------------------------------

di as result _n "=== 2014 FULL SAMPLE ===" _n
eststo clear

eststo r1: qui oprobit acachieve_rev same_sex immigrant_origin ///
    i.female i.agecat i.welloff [pw=weight] if wave==2014 & sample_main_full, vce(cluster school)
capture estadd scalar ll   = e(ll)
capture estadd scalar r2_p = e(r2_p)

eststo r2: qui reg acachieve_rev same_sex immigrant_origin ///
    i.female i.agecat i.welloff [pw=weight] if wave==2014 & sample_main_full, vce(cluster school)
capture estadd scalar r2  = e(r2)

esttab r1 r2 using "$TABLES/table9_2014_full.tex", ///
    replace `esttab_opts' `reg_opts' ///
    keep(same_sex immigrant_origin) ///
    stats(N ll r2_p r2, fmt(%9.0fc %9.3f %9.3f %9.3f) ///
          labels("Observations" "Log likelihood" "Pseudo R^2" "R^2")) ///
    mtitles("O.Probit" "OLS") ///
    title("2014 Full Sample Robustness Check\label{tab:2014full}") ///
    addnotes("Sample: All families with 1+ siblings (2014 wave only)." ///
             "Results subject to composition bias from parental fertility decisions." ///
             "Main analysis (Table \ref{tab:wave2014}) uses single-sibling sample." ///
             "Controls: child sex, age, family affluence. SE clustered at school.")
			 
* List generated tables
capture {
    ! ls -lh "$TABLES"/table*.tex
    ! ls -lh "$TABLES"/appendix*.tex
}

log close
