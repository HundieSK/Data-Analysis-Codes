*-----------------------------------------
* 1. Load country data and keep one observation per country
*-----------------------------------------
use "E:\SSA EKC 2025\World Data ESG Final Data2025.dta", clear

bysort C_ID (year): keep if _n == 1     // keep first year per country
keep C_ID ISO3 latitude longitude
save "country_coordinates.dta", replace

*-----------------------------------------
* 2. Create all pairs of countries (long format)
*-----------------------------------------
use "country_coordinates.dta", clear
rename (C_ID ISO3 latitude longitude) =_i  
cross using "country_coordinates.dta"
rename (C_ID ISO3 latitude longitude) =_j
* Exclude self-pairs
drop if C_ID_i == C_ID_j

*-----------------------------------------
* 3. Compute great-circle distances
*-----------------------------------------
geodist latitude_i longitude_i latitude_j longitude_j, gen(distance_km) sphere

*-----------------------------------------
* 4. Identify K nearest neighbors (K=5)
*-----------------------------------------
sort C_ID_i distance_km
by C_ID_i: gen rank = _n
keep if rank <= 5        // keep 5 nearest neighbors only

*-----------------------------------------
* 5. Create binary weights
*-----------------------------------------
gen weight = 1

*-----------------------------------------
* 6. Reshape to wide format (one row per country)
*-----------------------------------------
keep C_ID_i C_ID_j weight
reshape wide weight, i(C_ID_i) j(C_ID_j)

* Replace missing values with 0
ds C_ID_i weight*
foreach var of varlist `r(varlist)' {
    replace `var' = 0 if missing(`var')
}

*-----------------------------------------
* 7. Create matrix for spatial operations
*-----------------------------------------
mkmat weight*, matrix(W) rownames(C_ID_i) nomissing
save "knn_weights.dta", replace
drop C_ID_i
save "knn_weights.dta", replace
* Import matrix as spmatrix
spatwmat using knn_weights.dta, name(W)

*-----------------------------------------
* 8. Optional: ensure strictly binary
*-----------------------------------------
use "knn_weights.dta", clear
foreach var of varlist weight* {
    replace `var' = 0 if missing(`var')
    assert inlist(`var', 0, 1)
}
mkmat weight*, matrix(W_binary) rownames(C_ID_i) nomissing
