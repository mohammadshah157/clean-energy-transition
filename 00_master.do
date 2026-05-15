/*==============================================================
  00_master.do
  Clean Energy & Child ARI — NFHS DiD Project
  Stata 17
==============================================================*/

clear all
set more off

* ── Set your folder path here ──
global root    "C:/Users/YourName/clean_energy_ari"
global raw     "$root/data/raw"
global out     "$root/data/processed"
global tables  "$root/outputs/tables"
global figures "$root/outputs/figures"
global do      "$root/do"

* Create folders
capture mkdir "$root/data"
capture mkdir "$root/data/raw"
capture mkdir "$root/data/processed"
capture mkdir "$root/outputs"
capture mkdir "$root/outputs/tables"
capture mkdir "$root/outputs/figures"

* Install packages (run once)
capture ssc install reghdfe,   replace
capture ssc install ivreghdfe, replace
capture ssc install estout,    replace
capture ssc install coefplot,  replace
capture ssc install ftools,    replace
capture reghdfe, compile

log using "$root/log.txt", replace text

do "$do/01_data_preparation.do"
do "$do/02_descriptive_stats.do"
do "$do/03_did_analysis.do"
do "$do/04_iv_analysis.do"

log close
di as result "✓ All done. Check outputs/ for tables and figures."
