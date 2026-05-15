/*==============================================================
  02_descriptive_stats.do
  Summary tables and parallel trends figure
==============================================================*/

clear all
set more off

global out     "D:\Projects (ongoing)\Clean Energy transition and Respiratory health\outputs"
global tables  "D:\Projects (ongoing)\Clean Energy transition and Respiratory health\outputs/tables"
global figures "D:\Projects (ongoing)\Clean Energy transition and Respiratory health\outputs/figures"

use "$out/df_clean.dta", clear
estimates clear


/*--------------------------------------------------------------
  TABLE 1: Weighted means by wave (NFHS-4 vs NFHS-5)
--------------------------------------------------------------*/

local vars ari ari_strict fever cough lpg solid_fuel indoor m_sec_edu male urban wealth m_age

estpost tabstat `vars' [aw = childwt], ///
    by(wave) statistics(mean sd) columns(statistics) nototal

esttab using "$tables/table1_summary.rtf", replace ///
    cells("mean(fmt(3) label(Mean)) sd(fmt(3) label(SD))") ///
    nostar nonumber noobs label ///
    mtitles("NFHS-4 (2015-16)" "NFHS-5 (2019-21)") ///
    title("Table 1. Summary Statistics by Wave") ///
    addnotes("Weighted using DHS child sampling weights.")

di as result "✓ Table 1 saved"


/*--------------------------------------------------------------
  TABLE 2: Balance check — treated vs control at baseline
--------------------------------------------------------------*/

preserve
    keep if wave == 0

    local bvars ari lpg solid_fuel indoor m_sec_edu urban wealth
    local nv : word count `bvars'

    matrix B = J(`nv', 4, .)
    matrix rownames B = `bvars'
    matrix colnames B = "Control" "Treated" "Difference" "p_value"

    local i = 1
    foreach v of local bvars {
        qui summarize `v' [aw = hhwt] if treated == 0
        matrix B[`i', 1] = r(mean)
        qui summarize `v' [aw = hhwt] if treated == 1
        matrix B[`i', 2] = r(mean)
        qui ttest `v', by(treated)
        matrix B[`i', 3] = r(mu_2) - r(mu_1)
        matrix B[`i', 4] = r(p)
        local ++i
    }

    matrix list B, format(%9.3f) title("Table 2. Baseline Balance")

    putexcel set "$tables/table2_balance.xlsx", replace
    putexcel A1 = "Table 2. Baseline Balance: Treated vs Control (NFHS-4)"
    putexcel A3 = matrix(B), names nformat(%9.3f)
restore

di as result "✓ Table 2 saved"


/*--------------------------------------------------------------
  FIGURE 1: Parallel trends — ARI rate by group over time
--------------------------------------------------------------*/

preserve
    collapse (mean) ari_mean = ari ///
			 (count) N = ari ///
			 (sd) ari_sd = ari ///
             [aw = childwt], by(treated wave)
			 
	gen ari_se = ari_sd /sqrt(N)

    gen ci_lo  = ari_mean - 1.96 * ari_se
    gen ci_hi  = ari_mean + 1.96 * ari_se
    gen period = wave + 1

    twoway ///
        (connected ari_mean period if treated == 0, ///
            lcolor("67 147 195") mcolor("67 147 195") msymbol(circle) lwidth(medthick)) ///
        (rcap ci_lo ci_hi period if treated == 0, lcolor("67 147 195") lwidth(thin)) ///
        (connected ari_mean period if treated == 1, ///
            lcolor("230 99 70") mcolor("230 99 70") msymbol(triangle) lwidth(medthick)) ///
        (rcap ci_lo ci_hi period if treated == 1, lcolor("230 99 70") lwidth(thin)), ///
        xlabel(1 `""NFHS-4" "(2015-16)""' 2 `""NFHS-5" "(2019-21)""', labsize(small)) ///
        ylabel(, format(%5.3f) labsize(small)) ///
        ytitle("Proportion of Children with ARI", size(small)) ///
        xtitle("") ///
        legend(order(1 "Low LPG (Control)" 3 "High LPG (Treated)") pos(6) rows(1) size(small)) ///
        title("ARI Rates Over Time by District Group", size(medsmall)) ///
        subtitle("95% CI shown | Weighted", size(small) color(gray)) ///
        note("Source: NFHS-4 & NFHS-5, DHS Program", size(vsmall)) ///
        graphregion(color(white)) scheme(s2color)

    graph export "$figures/fig1_parallel_trends.png", replace width(2700)
restore

di as result "✓ Figure 1 saved"


/*--------------------------------------------------------------
  FIGURE 2: Histogram of baseline district LPG rates
--------------------------------------------------------------*/

use "$out/district_baseline.dta", clear
summarize base_lpg, detail
local med = r(p50)

histogram base_lpg, ///
    frequency color("67 147 195%70") lcolor(white) ///
    xline(`med', lcolor("230 99 70") lpattern(dash) lwidth(medthick)) ///
    xtitle("District LPG Rate at Baseline", size(small)) ///
    ytitle("Number of Districts", size(small)) ///
    title("Baseline LPG Adoption Across Districts", size(medsmall)) ///
    subtitle("Red line = median cutoff", size(small) color(gray)) ///
    note("Source: NFHS-4 (2015-16)", size(vsmall)) ///
    graphregion(color(white)) scheme(s2color)

graph export "$figures/fig2_lpg_distribution.png", replace width(2700)

di as result "✓ Figure 2 saved"


/*--------------------------------------------------------------
  QUICK CONSOLE CHECK
--------------------------------------------------------------*/

use "$out/df_clean.dta", clear
di _newline "ARI rate by wave and treatment:"
table wave treated [pw = childwt], statistic(mean ari) nformat(%6.4f)

di as result "✓ Descriptive stats complete"
