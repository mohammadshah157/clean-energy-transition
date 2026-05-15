/*==============================================================
  04_iv_analysis.do
  Instrumental Variables (IV/2SLS)
  Instrument: Bartik shift-share (baseline LPG rate × post wave)
  Addresses endogeneity: richer families self-select into LPG
  AND have healthier children — OLS conflates both effects
==============================================================*/

clear all
set more off

global out     "D:\Projects (ongoing)\Clean Energy transition and Respiratory health\outputs"
global tables  "D:\Projects (ongoing)\Clean Energy transition and Respiratory health\outputs/tables"


use "$out/df_clean.dta", clear
estimates clear


/*--------------------------------------------------------------
  STEP 1: FIRST STAGE
  Does our instrument (z_bartik) predict LPG adoption (did)?
  We need a strong first stage: F-statistic > 10
--------------------------------------------------------------*/

di _newline "=== FIRST STAGE ==="

reghdfe did z_bartik m_sec_edu male urban i.wealth, ///
    absorb(dist_id wave) vce(cluster dist_id)
estimates store first_stage

di "First stage coefficient on z_bartik: " %9.4f _b[z_bartik]
test z_bartik
di "First stage F-statistic: " %9.2f r(F)

if r(F) >= 10  di as result "✓ Strong instrument (F ≥ 10)"
else           di as error  "⚠ Weak instrument (F < 10) — IV results unreliable"


/*--------------------------------------------------------------
  STEP 2: REDUCED FORM
  Does the instrument directly predict ARI?
  (Total effect of instrument on outcome through all channels)
--------------------------------------------------------------*/

di _newline "=== REDUCED FORM ==="

reghdfe ari z_bartik m_sec_edu male urban i.wealth, ///
    absorb(dist_id wave) vce(cluster dist_id)
estimates store reduced_form

di "Reduced form coef on z_bartik: " %9.4f _b[z_bartik]


/*--------------------------------------------------------------
  STEP 3: IV/2SLS ESTIMATION
  Syntax: ivreghdfe outcome controls (endogenous = instrument)
  Stage 1: did ~ z_bartik + controls + FE  →  fitted values
  Stage 2: ari ~ fitted_did + controls + FE
  The coefficient on did is the causal IV estimate (LATE)
--------------------------------------------------------------*/

di _newline "=== IV/2SLS ==="

ivreghdfe ari m_sec_edu male urban i.wealth ///
    (did = z_bartik), ///
    absorb(dist_id wave) cluster(dist_id)
estimates store iv_2sls

di "IV estimate on did: " %9.4f _b[did]


/*--------------------------------------------------------------
  STEP 4: OLS TWFE for side-by-side comparison
--------------------------------------------------------------*/

reghdfe ari did m_sec_edu male urban i.wealth, ///
    absorb(dist_id wave) vce(cluster dist_id)
estimates store ols_twfe


/*--------------------------------------------------------------
  STEP 5: EXPORT COMPARISON TABLE
  Columns: First Stage | Reduced Form | OLS | IV
  Compare OLS vs IV — if IV > OLS in magnitude, selection bias exists
--------------------------------------------------------------*/

esttab first_stage reduced_form ols_twfe iv_2sls ///
    using "$tables/table5_iv.rtf", replace ///
    b(4) se(4) star(* 0.10 ** 0.05 *** 0.01) ///
    keep(did z_bartik m_sec_edu male urban) ///
    order(did z_bartik m_sec_edu male urban) ///
    varlabels(did      "DiD / Endogenous variable" ///
              z_bartik "Instrument (Bartik)") ///
    scalars("N Observations") ///
    mtitles("First Stage" "Reduced Form" "OLS-TWFE" "IV/2SLS") ///
    title("Table 5. IV Results: LPG Adoption and Child ARI") ///
    addnotes("Instrument: Bartik shift-share (baseline LPG rate × wave)." ///
             "District + Wave FE in all models. SEs clustered at district." ///
             "*** p<0.01 ** p<0.05 * p<0.10")

di as result "✓ Table 5 saved"


/*--------------------------------------------------------------
  STEP 6: OLS vs IV COMPARISON
  If |IV| > |OLS| → wealthier families self-select into LPG
  and OLS underestimates the true health benefit
--------------------------------------------------------------*/

estimates restore ols_twfe
scalar ols = _b[did]

estimates restore iv_2sls
scalar iv  = _b[did]

di _newline "==================================================="
di "OLS DiD estimate : " %9.4f ols
di "IV  DiD estimate : " %9.4f iv
di "Difference (IV-OLS): " %9.4f iv - ols
di "==================================================="

if abs(iv) > abs(ols) {
    di as result "→ Selection bias confirmed. IV estimate is more reliable."
}
else {
    di as text "→ OLS and IV similar. Selection bias appears small."
}

di as result "✓ IV analysis complete"
