/*==============================================================
  03_did_analysis.do
  Difference-in-Differences estimation
  Main model: Two-Way Fixed Effects (district + wave)
==============================================================*/

clear all
set more off

global out     "D:\Projects (ongoing)\Clean Energy transition and Respiratory health\outputs"
global tables  "D:\Projects (ongoing)\Clean Energy transition and Respiratory health\outputs/tables"
global figures "D:\Projects (ongoing)\Clean Energy transition and Respiratory health\outputs/figures"

use "$out/df_clean.dta", clear
estimates clear


/*--------------------------------------------------------------
  MODEL 1: Naive DiD — no controls, no fixed effects
  ARI = b0 + b1*treated + b2*wave + b3*did + error
  b3 is the DiD estimate (effect of LPG adoption on ARI)
--------------------------------------------------------------*/

regress ari treated wave did [pweight = childwt], vce(cluster dist_id)
estimates store m1
estadd local fe "No"


/*--------------------------------------------------------------
  MODEL 2: DiD + covariates
  Adds mother education, child sex, urban, wealth, indoor cooking
--------------------------------------------------------------*/

regress ari treated wave did m_sec_edu male urban i.wealth indoor ///
        [pweight = childwt], vce(cluster dist_id)
estimates store m2
estadd local fe "No"


/*--------------------------------------------------------------
  MODEL 3: Two-Way Fixed Effects (TWFE) — main specification
  Absorbs district FE (controls for all district-level time-invariant
  factors) and wave FE (controls for nationwide time trends)
  Standard errors clustered at district level
--------------------------------------------------------------*/

reghdfe ari did m_sec_edu male urban i.wealth indoor, ///
    absorb(dist_id wave) vce(cluster dist_id)
estimates store m3
estadd local fe "District + Wave"


/*--------------------------------------------------------------
  MODEL 4: TWFE with strict ARI outcome (robustness check)
--------------------------------------------------------------*/

reghdfe ari_strict did m_sec_edu male urban i.wealth indoor, ///
    absorb(dist_id wave) vce(cluster dist_id)
estimates store m4
estadd local fe "District + Wave"


/*--------------------------------------------------------------
  EXPORT MAIN TABLE
--------------------------------------------------------------*/

esttab m1 m2 m3 m4 using "$tables/table3_did.rtf", replace ///
    b(4) se(4) star(* 0.10 ** 0.05 *** 0.01) ///
    keep(did m_sec_edu male urban indoor) ///
    order(did m_sec_edu male urban indoor) ///
    varlabels(did          "DiD Estimate (Treated × Post)" ///
              m_sec_edu    "Mother Secondary Edu+" ///
              male         "Male Child" ///
              urban        "Urban Household" ///
              indoor       "Indoor Kitchen") ///
    scalars("fe Fixed Effects" "N Observations") ///
    mtitles("Naive DiD" "DiD+Controls" "TWFE" "TWFE Strict ARI") ///
    title("Table 3. DiD Estimates: LPG Adoption and Child ARI") ///
    addnotes("SEs clustered at district level." "*** p<0.01 ** p<0.05 * p<0.10")

di as result "✓ Table 3 saved"


/*--------------------------------------------------------------
  HETEROGENEITY: Urban vs Rural
--------------------------------------------------------------*/

reghdfe ari did m_sec_edu male i.wealth if urban == 1, ///
    absorb(dist_id wave) vce(cluster dist_id)
estimates store h_urban

reghdfe ari did m_sec_edu male i.wealth if urban == 0, ///
    absorb(dist_id wave) vce(cluster dist_id)
estimates store h_rural


/*--------------------------------------------------------------
  HETEROGENEITY: By wealth quintile
--------------------------------------------------------------*/

forvalues q = 1/5 {
    reghdfe ari did m_sec_edu male if wealth == `q', ///
        absorb(dist_id wave) vce(cluster dist_id)
    estimates store h_wq`q'
}


/*--------------------------------------------------------------
  EXPORT HETEROGENEITY TABLE
--------------------------------------------------------------*/

esttab h_urban h_rural h_wq1 h_wq2 h_wq3 h_wq4 h_wq5 ///
    using "$tables/table4_heterogeneity.rtf", replace ///
    b(4) se(4) star(* 0.10 ** 0.05 *** 0.01) ///
    keep(did) varlabels(did "DiD Estimate") ///
    scalars("N Observations") ///
    mtitles("Urban" "Rural" "Q1" "Q2" "Q3" "Q4" "Q5") ///
    title("Table 4. Heterogeneity Analysis") ///
    addnotes("All models: District + Wave FE. SEs clustered at district.")

di as result "✓ Table 4 saved"


/*--------------------------------------------------------------
  FIGURE 3: Coefficient plot of DiD across subgroups
--------------------------------------------------------------*/

coefplot ///
    (m3,     label("Main TWFE"))          ///
    (h_urban, label("Urban"))             ///
    (h_rural, label("Rural"))             ///
    (h_wq1,  label("Wealth Q1 (Poorest)")) ///
    (h_wq2,  label("Wealth Q2"))          ///
    (h_wq3,  label("Wealth Q3"))          ///
    (h_wq4,  label("Wealth Q4"))          ///
    (h_wq5,  label("Wealth Q5 (Richest)")), ///
    keep(did) ///
    xline(0, lcolor(gray) lpattern(dash)) ///
    msymbol(circle) mcolor("230 99 70") ///
    ciopts(lcolor("67 147 195") lwidth(medthick)) ///
    xtitle("DiD Estimate (Change in ARI probability)", size(small)) ///
    title("DiD Estimates Across Subgroups", size(medsmall)) ///
    subtitle("Point estimates with 95% CIs", size(small) color(gray)) ///
    graphregion(color(white)) scheme(s2color)

graph export "$figures/fig3_coefplot.png", replace width(2700)

di as result "✓ Figure 3 saved"


/*--------------------------------------------------------------
  PLACEBO TEST: Random fake time split within NFHS-4
  If DiD is real, this fake DiD should be insignificant
--------------------------------------------------------------*/

preserve
    keep if wave == 0
    set seed 42
    gen fake_wave = (runiform() > 0.5)
    gen fake_did  = treated * fake_wave

    reghdfe ari fake_did m_sec_edu male urban i.wealth, ///
        absorb(dist_id) vce(cluster dist_id)

    di _newline "=== PLACEBO TEST (should be insignificant) ==="
    di "Placebo DiD coef = " %9.4f _b[fake_did]
    di "p-value          = " %9.4f 2*ttail(e(df_r), abs(_b[fake_did]/_se[fake_did]))
restore

di as result "✓ DiD analysis complete"
