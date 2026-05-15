# Clean Energy Transition & Child Respiratory Health
### Difference-in-Differences Analysis using NFHS-4 and NFHS-5 | Stata 17

---

## Research Question
Has the adoption of clean cooking fuels (LPG) significantly reduced the incidence of Acute Respiratory Infections (ARI) in children under five in India?

---

## Data

You need four files from the DHS Program (https://dhsprogram.com). Register for free and request access to India NFHS datasets.

| File | Survey | What it contains |
|------|--------|-----------------|
| `IAHR71FL.DTA` | NFHS-4 (2015-16) | Household: cooking fuel, kitchen, wealth |
| `IAHR7AFL.DTA` | NFHS-5 (2019-21) | Household: cooking fuel, kitchen, wealth |
| `IAKR74FL.DTA` | NFHS-4 (2015-16) | Children: fever, cough, rapid breathing |
| `IAKR7AFL.DTA` | NFHS-5 (2019-21) | Children: fever, cough, rapid breathing |

Place all four files in: `data/raw/`

---

## Project Structure

```
clean_energy_ari/
├── do/
│   ├── 00_master.do            ← Run this file to execute everything
│   ├── 01_data_preparation.do
│   ├── 02_descriptive_stats.do
│   ├── 03_did_analysis.do
│   └── 04_iv_analysis.do
├── data/
│   ├── raw/                    ← Place your 4 NFHS .DTA files here
│   └── processed/              ← Auto-created cleaned datasets
└── outputs/
    ├── tables/                 ← Regression tables (.rtf, .xlsx)
    └── figures/                ← Plots (.png)
```

---

## How to Run

1. Open `00_master.do`
2. Change the `global root` path to your project folder
3. Do the same in scripts 01–04 (the two path lines at the top of each)
4. In Stata, run:
```stata
do "C:/YourPath/do/00_master.do"
```
Everything runs automatically in order.

---

## What Each Script Does

| Script | Purpose | Key Output |
|--------|---------|------------|
| `01_data_preparation.do` | Loads and merges NFHS files, builds ARI outcome, assigns treated/control districts | `df_clean.dta` |
| `02_descriptive_stats.do` | Summary tables, balance check, parallel trends plot | Table 1, Table 2, Figure 1, Figure 2 |
| `03_did_analysis.do` | DiD regressions, heterogeneity, placebo test, coefficient plot | Table 3, Table 4, Figure 3 |
| `04_iv_analysis.do` | IV/2SLS, first stage, reduced form, OLS vs IV comparison | Table 5 |

---

## Key Variables

### Outcome
| Variable | Definition |
|----------|-----------|
| `ari` | = 1 if child had fever AND cough in last 2 weeks |
| `ari_strict` | = 1 if fever + cough + rapid breathing |

### Treatment
| Variable | Definition |
|----------|-----------|
| `lpg` | = 1 if household uses LPG/electricity/biogas (clean fuel) |
| `treated` | = 1 if district had above-median LPG adoption at NFHS-4 baseline |
| `did` | = treated × wave (the DiD interaction — this is β₃) |

### Controls
| Variable | Definition |
|----------|-----------|
| `m_sec_edu` | Mother has secondary education or higher |
| `male` | Male child |
| `urban` | Urban household |
| `wealth` | Wealth index quintile (1=poorest, 5=richest) |
| `indoor` | Kitchen is indoors |

---

## Econometric Strategy

### Difference-in-Differences (Script 03)
```
ARI = β0 + β1·treated + β2·wave + β3·did + controls + district FE + wave FE + ε
```
- **β3 is the main result** — the Average Treatment Effect on the Treated (ATT)
- A negative β3 means ARI fell more in high-LPG districts than low-LPG districts
- District fixed effects absorb geography, infrastructure, culture
- Wave fixed effects absorb national trends (economic shocks, health campaigns)
- Standard errors clustered at district level

### Instrumental Variables (Script 04)
Fuel choice is potentially endogenous — wealthier families adopt LPG AND have healthier children. IV separates these effects.

**Instrument:** Bartik shift-share = baseline district LPG rate × post-period indicator
- Districts with more pre-existing LPG infrastructure saw larger post-PMUY gains
- This variation is exogenous to individual household health preferences

Check the **first-stage F-statistic** (must be > 10 for a strong instrument).

---

## Packages Required
Run once before your first use:
```stata
ssc install reghdfe,   replace
ssc install ivreghdfe, replace
ssc install estout,    replace
ssc install coefplot,  replace
ssc install ftools,    replace
```
Or just run `00_master.do` — it installs them automatically.

---

## Outputs

| File | Description |
|------|-------------|
| `table1_summary.rtf` | Weighted means: NFHS-4 vs NFHS-5 |
| `table2_balance.xlsx` | Baseline balance: treated vs control |
| `table3_did.rtf` | Main DiD regression results |
| `table4_heterogeneity.rtf` | Results by urban/rural and wealth quintile |
| `table5_iv.rtf` | IV/2SLS results vs OLS |
| `fig1_parallel_trends.png` | ARI trends over time by group |
| `fig2_lpg_distribution.png` | Baseline LPG rate distribution across districts |
| `fig3_coefplot.png` | DiD coefficients across subgroups |

---

*National Family Health Survey (NFHS-4 and NFHS-5), India.*
Mumbai: IIPS. Available at: https://dhsprogram.com
