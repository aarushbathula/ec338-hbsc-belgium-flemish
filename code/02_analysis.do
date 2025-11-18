*******************************************************
* 02_analysis.do – All Model Estimation (no export)
*******************************************************

version 18
clear all
set more off

* Assumes PROJ is defined in master.do.
* If running standalone, uncomment and set:
* global PROJ "/Users/aarushbathula/Developer/ec338-hbsc-belgium-flemish"

global FINAL "$PROJ/data/final"
global TABLES "$PROJ/output/tables"

use "$FINAL/hbsc_pooled_BEFL_final.dta", clear

* Female dummy
capture drop female
gen female = (sex == 2)

*******************************************************
* Main models (Tables 3–9)
*******************************************************

eststo clear

*------------------------------------------------------
* Table 3 models – Main results
*------------------------------------------------------

* Col 1: Oprobit (no controls)
eststo m1: oprobit acachieve_rev same_sex ///
    [pw=weight] if sample_main_single, vce(cluster school)

* Col 2: Oprobit (controls)
eststo m2: oprobit acachieve_rev same_sex i.female i.agecat i.welloff ///
    [pw=weight] if sample_main_single, vce(cluster school)

* Col 3: Oprobit (controls + wave FE)
eststo m3: oprobit acachieve_rev same_sex i.female i.agecat i.wave i.welloff ///
    [pw=weight] if sample_main_single, vce(cluster school)

* Col 4: OLS
eststo m4: regress acachieve_rev same_sex i.female i.agecat i.wave i.welloff ///
    [pw=weight] if sample_main_single, vce(cluster school)

*------------------------------------------------------
* Table 4 – Marginal effects
*------------------------------------------------------

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

*------------------------------------------------------
* Table 5 – Heterogeneity
*------------------------------------------------------

eststo clear

* By sex
eststo h1: oprobit acachieve_rev c.same_sex##i.female ///
    i.agecat i.wave i.welloff ///
    [pw=weight] if sample_main_single, vce(cluster school)

* By age
eststo h2: oprobit acachieve_rev c.same_sex##i.agecat ///
    i.female i.wave i.welloff ///
    [pw=weight] if sample_main_single, vce(cluster school)

* By affluence (linear interaction)
eststo h3: oprobit acachieve_rev c.same_sex##c.welloff ///
    i.female i.agecat i.wave ///
    [pw=weight] if sample_main_single, vce(cluster school)

*------------------------------------------------------
* Table 6 – Multi-sibling composition
*------------------------------------------------------

eststo clear

eststo comp1: oprobit acachieve_rev boy_both_sib girl_both_sib only_same_sex ///
    i.female i.agecat i.wave i.welloff ///
    [pw=weight] if sample_multi_only, vce(cluster school)

eststo comp2: regress acachieve_rev boy_both_sib girl_both_sib only_same_sex ///
    i.female i.agecat i.wave i.welloff ///
    [pw=weight] if sample_multi_only, vce(cluster school)

*------------------------------------------------------
* Table 7 – 2014 mechanisms (immigrant origin & trust)
*------------------------------------------------------

eststo clear

eststo w1: oprobit acachieve_rev same_sex immigrant_origin ///
    i.female i.agecat i.welloff ///
    [pw=weight] if wave == 2014 & sample_main_single, vce(cluster school)

eststo w2: regress acachieve_rev same_sex immigrant_origin ///
    i.female i.agecat i.welloff ///
    [pw=weight] if wave == 2014 & sample_main_single, vce(cluster school)

eststo w3: oprobit acachieve_rev c.same_sex##i.teacher_trust3 immigrant_origin ///
    i.female i.agecat i.welloff ///
    [pw=weight] if wave == 2014 & sample_main_single, vce(cluster school)

*------------------------------------------------------
* Table 8 – Composition-by-age (multi-sibling)
*------------------------------------------------------

eststo clear

eststo ca1: oprobit acachieve_rev ///
    c.boy_both_sib##i.agecat ///
    c.girl_both_sib##i.agecat ///
    only_same_sex ///
    i.female i.wave i.welloff ///
    [pw=weight] if sample_multi_only, vce(cluster school)

*------------------------------------------------------
* Table 9 – 2014 full sample robustness
*------------------------------------------------------

eststo clear

eststo r1: oprobit acachieve_rev same_sex immigrant_origin ///
    i.female i.agecat i.welloff ///
    [pw=weight] if wave == 2014 & sample_main_full, vce(cluster school)

eststo r2: regress acachieve_rev same_sex immigrant_origin ///
    i.female i.agecat i.welloff ///
    [pw=weight] if wave == 2014 & sample_main_full, vce(cluster school)

*******************************************************
* End 02_analysis.do
*******************************************************
