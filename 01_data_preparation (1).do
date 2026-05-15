/*==============================================================
  01_data_preparation.do
  Loads NFHS-4 and NFHS-5, cleans, merges, builds DiD variables
==============================================================*/

clear all
set more off

global raw    "D:\Projects (ongoing)\Clean Energy transition and Respiratory health\data\raw"
global out    "D:\Projects (ongoing)\Clean Energy transition and Respiratory health\outputs"
capture mkdir "$out"

/*--------------------------------------------------------------
  STEP 1: NFHS-4 HOUSEHOLD RECODE
  hv226 = cooking fuel | hv228 = kitchen location
  hv270 = wealth index | hv025 = urban/rural
--------------------------------------------------------------*/

use hv001 hv002 hv005 hv024 hv025 hv226 hv228 hv270 shdistri ///
    using "$raw\nfhs4\IAHR74FL.DTA", clear

rename hv001    cluster_id
rename hv002    hh_id
rename hv005    wt_raw
rename hv024    state
rename hv025    urban_rural
rename hv226    fuel
rename hv228    kitchen
rename hv270    wealth
rename shdistri district

gen wave  = 0
gen hhwt  = wt_raw / 1000000

* Clean fuel = electricity(1) LPG(2) natural gas(3) biogas(4)
gen lpg        = inrange(fuel, 1, 4)  if !missing(fuel)
gen solid_fuel = inrange(fuel, 6, 11) if !missing(fuel)
gen indoor     = (kitchen == 1)       if !missing(kitchen)
gen urban      = (urban_rural == 1)   if !missing(urban_rural)

keep cluster_id hh_id state district wave hhwt wealth lpg solid_fuel indoor urban
save "$out/hh4.dta", replace


/*--------------------------------------------------------------
  STEP 2: NFHS-5 HOUSEHOLD RECODE
--------------------------------------------------------------*/

capture use hv001 hv002 hv005 hv024 hv025 hv226 hv228 hv270 shdistri ///
            using "$raw/nfhs5/IAHR7EFL.DTA", clear

if _rc != 0 {
    use hv001 hv002 hv005 hv024 hv025 hv226 hv228 hv270 ///
        using "$raw/nfhs5/IAHR7EFL.DTA", clear
    gen shdistri = hv024
    di as error "WARNING: district var missing in NFHS-5, using state"
}

rename hv001    cluster_id
rename hv002    hh_id
rename hv005    wt_raw
rename hv024    state
rename hv025    urban_rural
rename hv226    fuel
rename hv228    kitchen
rename hv270    wealth
rename shdistri district

gen wave  = 1
gen hhwt  = wt_raw / 1000000

gen lpg        = inrange(fuel, 1, 4)  if !missing(fuel)
gen solid_fuel = inrange(fuel, 6, 11) if !missing(fuel)
gen indoor     = (kitchen == 1)       if !missing(kitchen)
gen urban      = (urban_rural == 1)   if !missing(urban_rural)

keep cluster_id hh_id state district wave hhwt wealth lpg solid_fuel indoor urban
save "$out/hh5.dta", replace

use "$out/hh4.dta", clear
append using "$out/hh5.dta"
save "$out/hh_all.dta", replace


/*--------------------------------------------------------------
  STEP 3: NFHS-4 CHILDREN'S RECODE
  h1 = fever last 2 wks | h9 = cough last 2 wks
  h31 = rapid breathing | v106 = mother education
  b19 = age in months   | b5  = child alive
--------------------------------------------------------------*/

use v001 v002 v005 v012 v106 b4 b5 b8 h1 h9 h31 ///
    using "$raw/nfhs4/IAKR74FL.DTA", clear

keep if b5 == 1
keep if b8 <= 5 & !missing(b8)

rename v001 cluster_id
rename v002 hh_id
rename v005 wt_raw
rename v012 m_age
rename v106 m_edu
rename b4   sex
rename b8   age
rename h1   fever
rename h9   cough
rename h31  rapid

gen wave    = 0
gen childwt = wt_raw / 1000000

* ARI = fever + cough in last 2 weeks (WHO definition)
gen ari = 0
replace ari = 1 if fever == 1 & cough == 1
replace ari = . if missing(fever) | missing(cough)

* Strict ARI adds rapid breathing
gen ari_strict = 0
replace ari_strict = 1 if fever == 1 & cough == 1 & rapid == 1
replace ari_strict = . if missing(fever) | missing(cough) | missing(rapid)

gen male      = (sex == 1)   if !missing(sex)
gen m_sec_edu = (m_edu >= 2) if !missing(m_edu)

keep cluster_id hh_id wave childwt m_age m_sec_edu age male fever cough ari ari_strict
save "$out/kr4.dta", replace


/*--------------------------------------------------------------
  STEP 4: NFHS-5 CHILDREN'S RECODE
--------------------------------------------------------------*/

use v001 v002 v005 v012 v106 b4 b5 b19 h1 h9 h31 ///
    using "$raw/nfhs5/IAKR7EFL.DTA", clear

keep if b5 == 1
keep if b19 < 60 & !missing(b19)

rename v001 cluster_id
rename v002 hh_id
rename v005 wt_raw
rename v012 m_age
rename v106 m_edu
rename b4   sex
rename b19  age_mo
rename h1   fever
rename h9   cough
rename h31  rapid

gen wave    = 1
gen childwt = wt_raw / 1000000

gen ari = 0
replace ari = 1 if fever == 1 & cough == 1
replace ari = . if missing(fever) | missing(cough)

gen ari_strict = 0
replace ari_strict = 1 if fever == 1 & cough == 1 & rapid == 1
replace ari_strict = . if missing(fever) | missing(cough) | missing(rapid)

gen male      = (sex == 1)   if !missing(sex)
gen m_sec_edu = (m_edu >= 2) if !missing(m_edu)

keep cluster_id hh_id wave childwt m_age m_sec_edu age_mo male fever cough ari ari_strict
save "$out/kr5.dta", replace


/*--------------------------------------------------------------
  STEP 5: MERGE CHILDREN + HOUSEHOLD DATA
--------------------------------------------------------------*/

use "$out/kr4.dta", clear
append using "$out/kr5.dta"

merge m:1 cluster_id hh_id wave using "$out/hh_all.dta", ///
      keep(match) nogenerate

di "Merged: `=_N' child-observations"


/*--------------------------------------------------------------
  STEP 6: BUILD DISTRICT-LEVEL TREATMENT VARIABLE
  Treated = above median LPG adoption at NFHS-4 baseline
--------------------------------------------------------------*/

preserve
    keep if wave == 0
    collapse (mean) base_lpg = lpg [pweight = hhwt], by(district)
    summarize base_lpg, detail
    local med = r(p50)
    di "Median baseline LPG rate: `med'"
    gen treated    = (base_lpg > `med')
    xtile lpg_tile = base_lpg, nq(3)
    keep district base_lpg treated lpg_tile
    save "$out/district_baseline.dta", replace
restore

merge m:1 district using "$out/district_baseline.dta", keep(match) nogenerate


/*--------------------------------------------------------------
  STEP 7: FINAL VARIABLES AND SAVE
--------------------------------------------------------------*/

drop if missing(ari) | missing(lpg) | missing(treated) | missing(wealth)

* DiD interaction — the main variable of interest
* did = 1 means: treated district AND post-period (NFHS-5)
gen did = treated * wave

* Bartik instrument: post-period × baseline district LPG share (for Script 04)
gen z_bartik = wave * base_lpg

* Numeric district for fixed effects
capture confirm numeric variable district
if _rc != 0  encode district, gen(dist_id)
else         gen dist_id = district

svyset cluster_id [pweight = childwt], strata(state) singleunit(centered)

compress
save "$out/df_clean.dta", replace
di as result "✓ df_clean.dta ready — `=_N' observations"
