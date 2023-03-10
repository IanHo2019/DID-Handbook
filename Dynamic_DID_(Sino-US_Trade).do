* This do file runs various dynamic DID specifications using data on China's export to the US in 2000-2009.
* Author: Ian He
* Institution: The University of Oklahoma
* Date: Feb 26, 2023

clear all

global localdir "D:\research\DID Example"

global dtadir   "$localdir\Data"
global figdir   "$localdir\Figure"


*************************************************************************
use "$dtadir\CCD_GAD_USA_affirm.dta", clear

**# Create a series of dummies for duty impositions
gen period_duty = year - year_des_duty

gen Dn3 = (period_duty < -2)
forvalues i = 2(-1)1 {
	gen Dn`i' = (period_duty == -`i')
}

forvalues i = 0(1)3 {
	gen D`i' = (period_duty == `i')
}
gen D4 = (period_duty >= 4) & (period_duty != .)


**# Classical Dynamic DID
* install reghdfe ftools
encode hs06, generate(product) // string variables not allowed for xtset and regression

local dep = "value quantity company_num m_quantity"
foreach y in `dep'{
	quietly{		
		eststo reg_`y': reghdfe ln_`y' Dn3 Dn2 D0-D4, absorb(product year) vce(cluster product#year)
	}
}

estout reg*, keep(D*) ///
	coll(none) cells(b(star fmt(3)) se(par fmt(3))) ///
	starlevels(* .1 ** .05 *** .01) legend ///
	stats(N r2_a, nostar labels("Observations" "Adjusted R-Square") fmt("%9.0fc" 3))


**# Sun and Abraham (2021)
* install eventstudyinteract avar
gen first_union = year_des_duty
gen never_union = (first_union == .)

local dep = "value quantity company_num m_quantity"
foreach y in `dep'{	
	eventstudyinteract ln_`y' Dn3 Dn2 D0-D4, cohort(first_union) control_cohort(never_union) absorb(product year) vce(cluster product#year)
}


**# Borusyak, Jaravel & Spiess (2022)
* install did_imputation
gen id = product
egen clst = group(product year)
gen Ei = year_des_duty


local ylist = "value quantity company_num m_quantity"
foreach y in `ylist'{
	quietly{
		eststo reg_`y': did_imputation ln_`y' id year Ei, fe(product year) cluster(clst) horizons(0/4) pretrends(2) minn(0) autosample
	}
}

estout reg*, ///
	coll(none) cells(b(star fmt(3)) se(par fmt(3))) ///
	starlevels(* .1 ** .05 *** .01) legend ///
	stats(N r2_a, nostar labels("Observations" "Adjusted R-Square") fmt("%9.0fc" 3))


**# Visualization
* install event_plot
local ylist = "value quantity company_num m_quantity"
foreach y in `ylist'{
	if "`y'"=="value"{
		local panel = "A)"
		local title = "ln(Value)"
	}
	
	if "`y'"=="quantity"{
		local panel = "B)"
		local title = "ln(Total Quantity)"
	}
	
	if "`y'"=="company_num"{
		local panel = "C)"
		local title = "ln(Number of Exporters)"
	}
	
	if "`y'"=="m_quantity"{
		local panel = "D)"
		local title = "ln(Mean Quantity)"
	}
	
	event_plot reg_`y', default_look ///
	graph_opt( ///
		xtitle("Period") ytitle("Coefficient estimate") ///
		title("`panel' `title'", size(medlarge) position(11)) ///
		xlab(-2(1)3 4 "> 3", labsize(small)) ///
		ylab(, angle(90) nogrid labsize(small)) ///
		yline(0, lcolor(gs8) lpattern(dash)) ///
		name(reg_`y', replace) ///
	)
}

* install grc1leg: net install grc1leg.pkg, replace
grc1leg reg_value reg_quantity reg_company_num reg_m_quantity, ///
	legendfrom(reg_value) cols(2) ///
	graphregion(fcolor(white) lcolor(white)) ///
	name(four_panel, replace)

gr draw four_panel, ysize(5) xsize(6.5)
graph export "$figdir\Imputation_DID_Trade_Destruction.pdf", replace
