# Clean Energy Transition and Respiratory Health in India
### A Difference-in-Differences and IV Analysis Using NFHS Microdata


---

## Overview

This repository contains the full replication code for an empirical study examining the causal impact of India's **clean cooking fuel transition** — driven in large part by the *Pradhan Mantri Ujjwala Yojana* (PMUY) scheme — on **acute respiratory illness (ARI) in children under five**.

The analysis exploits variation in district-level LPG adoption rates across two waves of India's National Family Health Survey (NFHS-4: 2015–16 and NFHS-5: 2019–21) using a **Difference-in-Differences (DiD)** design, supplemented by **Instrumental Variables (2SLS)** to address the endogeneity of household fuel choice.

---

## Research Question

> *Does transitioning from solid biomass fuels to LPG/clean cooking energy causally reduce the incidence of acute respiratory illness in children under five in India?*

---

## Identification Strategy

### Difference-in-Differences
Districts are classified as **treated** (high LPG adoption) or **control** (low LPG adoption) based on their baseline LPG penetration rate in NFHS-4. The DiD estimator compares changes in child ARI rates between high- and low-adoption districts across the two survey waves, under the parallel trends assumption.

```
ARI_idt = β₀ + β₁·Treated_d + β₂·Post_t + β₃·(Treated_d × Post_t) + X_idt·δ + α_d + γ_t + ε_idt
```

`β₃` is the average treatment effect on the treated (ATT). District (`α_d`) and wave (`γ_t`) fixed effects are absorbed via `reghdfe`.

### Instrumental Variables (2SLS)
A **Bartik shift-share instrument** — the interaction of a district's baseline LPG adoption share with the post-wave indicator — instruments the endogenous DiD term. The Frisch-Waugh-Lovell (FWL) theorem is applied to partial out district and wave fixed effects before `ivreg2` estimation. Instrument strength is assessed using the **Kleibergen-Paap rk Wald F-statistic**, and endogeneity is formally tested via the **Durbin-Wu-Hausman test**.

---

## Data

| Source | Description | Waves Used |
|---|---|---|
| [DHS Program — NFHS](https://dhsprogram.com) | India Household Recode | NFHS-4 (2015–16), NFHS-5 (2019–21) |
| [DHS Program — NFHS](https://dhsprogram.com) | India Kids Recode (children under 5) | NFHS-4 (2015–16), NFHS-5 (2019–21) |

> **Access:** Microdata must be requested individually at [dhsprogram.com/data/new-user-registration.cfm](https://dhsprogram.com/data/new-user-registration.cfm). Registration is free. Files are provided in `.DTA` (Stata) format — no conversion needed.

### Key Variables

| Variable | DHS Code | Description |
|---|---|---|
| **ARI** (outcome) | `h1`, `h9` | Child had fever AND cough in last 2 weeks |
| **Strict ARI** (outcome) | `h1`, `h9`, `h31` | ARI + short/rapid breathing |
| **LPG user** (treatment) | `hv226` | Household uses LPG, natural gas, biogas, or electricity for cooking |
| **Solid fuel** | `hv226` | Household uses wood, dung, crop residue, coal, or charcoal |
| **Wealth index** | `hv270` | DHS wealth quintile (1=poorest, 5=richest) |
| **Mother's education** | `v106` | Secondary or higher education (binary) |
| **Urban/Rural** | `hv025` | Household location type |
| **Indoor kitchen** | `hv228` | Kitchen located inside the dwelling |

---

## Repository Structure

```
project_root/
│
├── do/
│   ├── 00_master.do               # Run all do-files in sequence
│   ├── 01_data_preparation.do     # Load, clean, and merge NFHS microdata
│   ├── 02_descriptive_stats.do    # Summary tables, balance checks, parallel trends
│   ├── 03_did_analysis.do         # DiD estimation (OLS, TWFE, Logit, heterogeneity)
│   ├── 04_iv_analysis.do          # IV/2SLS estimation and validity checks
│   └── 05_robustness.do           # Sensitivity analyses and falsification tests
│
├── data/
│   ├── raw/
│   │   ├── nfhs4/                 # Place NFHS-4 .DTA files here (IAHR71FL, IAKR74FL)
│   │   └── nfhs5/                 # Place NFHS-5 .DTA files here (IAHR7AFL, IAKR7AFL)
│   └── processed/                 # Auto-generated cleaned datasets (.dta)
│
├── outputs/
│   ├── tables/                    # Regression and summary tables (.rtf / .csv)
│   └── figures/                   # All plots (.png, 300 dpi)
│
├── .gitignore
├── LICENSE
└── README.md
```

> **Note:** The `data/raw/` folder is excluded from version control via `.gitignore`. You must obtain and place DHS microdata files locally before running the analysis.

---

## Do-Files

### `00_master.do` — Entry Point
Sets the global `$root` path macro and calls all downstream do-files in sequence via `do "$root/do/XX_script.do"`. Creates all required output directories with `capture mkdir`. **Start here.**

### `01_data_preparation.do` — Data Wrangling
- Loads NFHS-4 and NFHS-5 Household and Kids Recodes directly from `.DTA` format
- Extracts and renames key variables consistently across both waves
- Constructs outcome variables: `ari` (fever + cough) and `ari_strict` (+ rapid breathing); children outside the under-5 age range are dropped (`keep if under5 == 1`)
- Classifies households as LPG/clean fuel users (`lpg_user`) vs. solid fuel users (`solid_fuel`)
- Stacks waves with `append`, merges household and child records with `merge m:1`
- Computes district-level baseline LPG adoption rates via `collapse (mean) ... if wave==0` and defines the **binary treatment indicator** (above/below median via `centile`)
- Creates the DiD interaction term `did_term = treated * wave`; encodes district and state for use as fixed effects
- Saves `df_clean.dta` and `district_baseline.dta` to `data/processed/`

### `02_descriptive_stats.do` — Exploratory Analysis
- Weighted summary statistics by survey wave exported via `estpost tabstat` + `esttab` (Table 1, `.rtf`)
- Baseline balance check using `estpost ttest ... , by(treated)` (Table 2, `.rtf`)
- **Parallel trends plot**: weighted ARI rates over time by treatment group via `twoway connected` + `rcap` for confidence intervals (Figure 1)
- Distribution of baseline LPG adoption rates across districts via `histogram` with median `xline` (Figure 2)
- State-level LPG and ARI cross-tabulation via `collapse` + `reshape wide`, exported to `.csv`

### `03_did_analysis.do` — DiD Estimation
Estimates four main specifications using `reghdfe` (high-dimensional FE absorber):

| Model | Stata Command | Description |
|---|---|---|
| (1) Naive DiD | `regress ari treated wave did_term` | No covariates; identifies raw ATT |
| (2) DiD + Controls | `regress ari ... covariates` | Adds child, mother, and household covariates |
| (3) TWFE | `reghdfe ari did_term ..., absorb(f_district wave)` | District + wave fixed effects |
| (4) TWFE — Strict ARI | `reghdfe ari_strict did_term ..., absorb(f_district wave)` | Stricter outcome definition |

Additionally estimates:
- **Logit DiD** via `xtlogit, fe` with average marginal effects via `margins, dydx(did_term)`
- **Urban/Rural heterogeneity** using `if urban==1` / `if urban==0` subsamples (Table 4)
- **Wealth quintile heterogeneity** via `forvalues q = 1/5` loop (Table 4)
- **Placebo test**: random within-wave pseudo-treatment (`gen placebo_wave = (runiform() > 0.5)`) to check pre-trends
- Coefficient plot across all subgroups using `postfile` + `twoway scatter/rcap` (Figure 3)
- All results exported to `.rtf` via `esttab`

### `04_iv_analysis.do` — IV/2SLS
- Constructs Bartik shift-share instrument: `gen z_bartik = wave * baseline_lpg_rate`
- **First stage** via `reghdfe lpg_user z_bartik ..., absorb(f_district wave)`: checks instrument relevance through the first-stage F-statistic stored in `e(F)`
- **Reduced form** via `reghdfe ari z_bartik ..., absorb(f_district wave)`
- **2SLS estimation**: FWL theorem applied — all variables residualized via `reghdfe` first, then `ivreg2` called on residuals; equivalent to TWFE-IV
- **Kleibergen-Paap rk Wald F-statistic** (`e(rkf)`) reported as the cluster-robust weak instrument test
- **Durbin-Wu-Hausman endogeneity test** via `ivreg2 ..., endog()`, p-value stored in `e(endogp)`
- **Exclusion restriction check**: regresses pre-period ARI on instrument with state FEs; near-zero coefficient supports validity
- Full comparison table: First Stage / Reduced Form / OLS-TWFE / IV (Table 5, `.rtf`)

### `05_robustness.do` — Sensitivity Analyses

| Check | Implementation | Description |
|---|---|---|
| Alternative thresholds | `centile` at p33/p66; new `did_p33`, `did_p66` | Sensitivity to treatment cutoff choice (Table R1) |
| Continuous treatment | `bysort district wave: egen dist_lpg_rate = wtmean(...)` | District LPG rate used directly instead of binary split |
| Placebo outcome | `reghdfe diarrhea did_term ...` | Effect on diarrhea (non-respiratory; should be zero) |
| Exclude metro states | `if !inlist(state, 7, 27, 33, 29)` | Results without Delhi, Maharashtra, Tamil Nadu, Karnataka |
| Robustness summary | `esttab` combining all specs | Single table across all specifications (Table R2) |
| Coefficient stability plot | `postfile` loop + `twoway` | Visual check of DiD estimate stability (Figure 4) |

---

## Setup and Replication

### 1. Prerequisites

- **Stata** ≥ 16 (MP, SE, or IC)
- Internet connection for first-time SSC package installation

### 2. Install User-Written Packages

All required packages are auto-installed from SSC on first run. To install manually:

```stata
ssc install reghdfe,   replace   // TWFE / high-dimensional FE regression
ssc install ftools,    replace   // dependency for reghdfe
ssc install ivreg2,    replace   // IV/2SLS with robust/clustered SEs
ssc install ranktest,  replace   // dependency for ivreg2 (weak IV tests)
ssc install estout,    replace   // regression tables (esttab, estout)
ssc install coefplot,  replace   // coefficient plots
ssc install distinct,  replace   // count distinct values
```

### 3. Obtain Data

1. Register at [dhsprogram.com](https://dhsprogram.com/data/new-user-registration.cfm)
2. Request access to India DHS datasets (NFHS-4 and NFHS-5)
3. Download the following files in **`.DTA` (Stata)** format:

| File | Wave | Type | Destination |
|---|---|---|---|
| `IAHR71FL.DTA` | NFHS-4 | Household Recode | `data/raw/nfhs4/` |
| `IAKR74FL.DTA` | NFHS-4 | Kids Recode | `data/raw/nfhs4/` |
| `IAHR7AFL.DTA` | NFHS-5 | Household Recode | `data/raw/nfhs5/` |
| `IAKR7AFL.DTA` | NFHS-5 | Kids Recode | `data/raw/nfhs5/` |

### 4. Set Working Directory

Open `00_master.do` and set the project root. The global macro `$root` propagates to all downstream do-files:

```stata
* Option A: Set explicitly
cd "/path/to/your/project"
global root "`c(pwd)'"

* Option B: If already in the project directory
global root "`c(pwd)'"
```

### 5. Run the Analysis

```stata
* Option A: Run everything at once (recommended)
do "do/00_master.do"

* Option B: Run do-files individually in order
do "do/01_data_preparation.do"
do "do/02_descriptive_stats.do"
do "do/03_did_analysis.do"
do "do/04_iv_analysis.do"
do "do/05_robustness.do"
```

---

## Outputs

All outputs are saved automatically to `outputs/`.

### Tables (`outputs/tables/`)

| File | Format | Contents |
|---|---|---|
| `table1_summary_stats.rtf` | Word/RTF | Weighted descriptive statistics by wave |
| `table1_summary_stats.txt` | Plain text | Quick-view summary statistics |
| `table2_balance.rtf` | Word/RTF | Baseline covariate balance: treated vs. control |
| `state_summary.csv` | CSV | State-level ARI and LPG rates by wave |
| `table3_did_results.rtf` | Word/RTF | Main DiD regression results (Models 1–4) |
| `table4_heterogeneity.rtf` | Word/RTF | Heterogeneity by urban/rural and wealth quintile |
| `table5_iv_results.rtf` | Word/RTF | First stage, reduced form, OLS vs. IV comparison |
| `table6_exclusion_check.rtf` | Word/RTF | Exclusion restriction validity check |
| `table5_placebo.rtf` | Word/RTF | Within-wave placebo test results |
| `robustness_thresholds.rtf` | Word/RTF | Alternative treatment threshold sensitivity |
| `robustness_summary.rtf` | Word/RTF | Robustness summary across all specifications |

### Figures (`outputs/figures/`)

| File | Contents |
|---|---|
| `fig1_parallel_trends.png` | ARI rates over time: treated vs. control districts |
| `fig2_district_lpg_dist.png` | Distribution of baseline LPG adoption across districts |
| `fig3_did_coefs.png` | DiD coefficient plot: main + subgroup estimates |
| `fig4_robustness_coefs.png` | Coefficient stability across robustness specifications |

---

## Econometric Notes

- **Fixed Effects**: District and wave FEs absorbed via `reghdfe` (Correia, 2017). `ftools` must be installed as a dependency.
- **Clustering**: All standard errors clustered at the **district level** (`vce(cluster f_district)`) to account for within-district correlation across households and waves.
- **Weights**: DHS child sampling weights (`v005 / 1,000,000`) applied via `[aw = childwt]` throughout. Household-level regressions use `hv005 / 1,000,000`.
- **TWFE-IV**: The Frisch-Waugh-Lovell theorem is used to partial out district and wave FEs via `reghdfe` residuals before calling `ivreg2`, since `ivreg2` does not natively support high-dimensional FE absorption.
- **Weak Instruments**: The **Kleibergen-Paap rk Wald F-statistic** (`e(rkf)`) is reported as the appropriate cluster-robust weak instrument test. Stock-Yogo (2005) 10% critical value ≈ 16.38 for one instrument.
- **Parallel Trends**: Visually assessed in Figure 1 and formally probed via a within-wave random placebo test in `03_did_analysis.do`.
- **Diarrhea Placebo** (in `05_robustness.do`): requires `h11` (diarrhea) to be extracted in `01_data_preparation.do`. A reminder with exact variable instructions is embedded in the script.
- **Metro State Codes**: Default codes in `05_robustness.do` are `7` (Delhi), `27` (Maharashtra), `33` (Tamil Nadu), `29` (Karnataka). Verify against your actual NFHS state coding before running.

---

## Citation

If you use this code, please cite as:

```
[Author Name(s)] (2025). Clean Energy Transition and Respiratory Health in India:
Evidence from NFHS DiD Analysis. GitHub repository.
https://github.com/[your-username]/[your-repo-name]
```

---

## License

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE) file for details. The underlying DHS microdata are subject to the [DHS Program data use agreement](https://dhsprogram.com/data/terms-of-use.cfm) and **cannot be redistributed**.

---

## Acknowledgements

- Microdata provided by the [DHS Program](https://dhsprogram.com), funded by USAID
- PMUY rollout data: [Ministry of Petroleum and Natural Gas, Government of India](https://www.pmujjwalayojana.com)
- `reghdfe`: Correia, S. (2017). *Linear Models with High-Dimensional Fixed Effects: An Efficient and Feasible Estimator.* Working Paper
- `ivreg2`: Baum, C.F., Schaffer, M.E., Stillman, S. (2010). *ivreg2: Stata module for extended instrumental variables/2SLS and GMM estimation.* SSC
- `estout`: Jann, B. (2007). *Making regression tables simplified.* Stata Journal, 7(2), 227–244
