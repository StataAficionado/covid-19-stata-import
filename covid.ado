// Module to import COVID-19 data from Github
// Koenraad Blot updated 25MAR2020

global EU "spain portugal france belgium netherlands denmark sweden norway finland germany ireland uk hungary slovakia slovenia austria poland romania malta luxembourg italy croatia latvia greece czech republic bosnia and herzegovina estonia"
global ylabel = "ylabel(, angle(horiz) labs(vsmall) format(%10.0fc) grid glstyle(dot) glw(vthin) glc(black%90)) "
capture program drop covid
program covid
	capture syntax namelist(min=1 name=countries) [, Force Newcases CUMulative COMParative]
	if _rc {
		di "Usage:"
		di
		di "covid countrylist(min=1) [, Force Newcases CUMulative COMParative]"
		di 
		di "countrylist (1 required) is a list of 1 or more countries, eg US Japan Italy"
		di "countrylist supplied is cases insensitive (all country names are converted to lower case)"
		di "Options:"
		di "	Force 		rebuilds the database from Github"
		di "	Newcases 	graphs new daily cases for specified countries"
		di "	CUMulative 	graphs cumulative confirmed cases for specified countries"
		di "	COMParative graphs comparative cases for specified countries"
	}
	local countries = ustrlower("`countries'")
	// change this to where you keep the covid.dta file
	cd ~/Documents
	// if the force option is not used, we see whether the file already exists 
	// and is up to date.
	if "`force'" == "" {
		capture use covid, clear
		if ! _rc {
			// the file exists and has now been read into memory. 
			// Check last date - if up to date, do not read from the online source
			qui summarize date 
			local lastdate = r(max)
			local today = td($S_DATE)
			// if the file is more than 1 day old, re-read the online data source
			if `lastdate' < `today' - 1 {
				readgithub
			}
		}
	}
	else {
		// the file is not found, so import the online source
		readgithub
	}
	// The covid.dta file is now saved in ~/Documents, run the other options
	if "`newcases'" != "" {
		gr_new `countries'
	}
	if "`cumulative'" != "" {
		gr_cum `countries'
	}
	if "`comparative'" != "" {
		gr_comparative `countries'
	}
end // covid


capture program drop gr_cum
program gr_cum
	// specify countries
	syntax namelist(min=1 name=countries)

	use covid, clear

	foreach country in `countries' {
		preserve
		qui keep if country == "`country'" & confirmed > 5
		tsset date
		twoway 	(tsline confirmed, 	recast(connected)) ///
///					(tsline deaths, recast(connected) yaxis(2)) ///
					, ///
					title(`country', size(small)) name(`country', replace) ///
					$ylabel
		restore	
	}
end // gr_cumcapture program drop gr_cum

capture program drop gr_new
program gr_new
	// specify countries
	syntax namelist(min=1 name=countries)

	use covid, clear
	foreach country in `countries' {
		preserve
		qui keep if country == "`country'" & confirmed > 5
		tsset date
		twoway	(tsline newcases, recast(bar)), $ylabel title("`country' new cases", size(small)) name(`country'_new, replace)
		restore	
	}
end // gr_cum

capture program drop gr_comparative
program gr_comparative
	syntax namelist(name=countries) [, LAG(real 100)]
	use covid, clear

	sort country date
	if "`countries'" == "" {
		local countries = "south_korea japan italy belgium france spain us"
	}
	// reset the timepoints to the point of 100 confirmed infections
	gen byte keep = 0
	// build command line for the twoway graph by adding lines for each country
	local cmd = "tw "
	local legendorder = 1
	local legendtext = ""
	foreach c in `countries' {
		replace keep = 1 if country == "`c'" & confirmed >= 100
		local cmd = `"`cmd' (tsline confirmed if country == "`c'", recast(connected) m(none) lw(medium)) "'
		local legendtext = `"`legendtext' `legendorder' "`c'"  "'
		local ++legendorder
	}
	keep if keep
	drop days
	tsset, clear
	bys _country: gen int days = _n

	// keep if days < 30 // & confirmed < 40000
	tsset _country days

	di "command line is:"
	di `"`cmd'"'
	di "legend text is: "
	di `"`legendtext'"'

	local legend = `"legend(order(`legendtext'))"'
	// local options = "ylabel(100 1000 10000 100000, angle(horiz) labs(vsmall) format(%10.0fc)) yscale(`log')"
	local options = "$ylabel yscale(`log')"
	// local options = "yscale(log)"
	`cmd', `legend' `options'


end // gr_comparative

capture program drop readgithub
program readgithub
	di "*** reading from Github ***"
	quietly {
		local githubroot = "https://raw.githubusercontent.com/CSSEGISandData/COVID-19/master/csse_covid_19_data/csse_covid_19_time_series"
		tempfile confirmed deaths 
		
		import delimited "`githubroot'/time_series_covid19_confirmed_global.csv", bindquote(strict) clear
		reformat confirmed
		save `confirmed'
		save confirmed, replace
		import delimited "`githubroot'/time_series_covid19_deaths_global.csv", bindquote(strict) clear
		reformat deaths
		save `deaths'

		use `confirmed', clear
		merge 1:1 country province date using `deaths', 	keepusing(deaths) 	gen(_deaths)

		replace province = "." if province == ""
		// The US data have doubles! Listing is for cities within states, then for states too.
		drop if country == "US" & strpos(province, ", ")
		replace country = "South Korea" if country == "Korea, South"
		replace country = usubinstr(country, " ", "_", .)
		replace country = ustrlower(country)
		replace province = ustrlower(province)

		collapse (sum) confirmed deaths, by(country date)

		sort country date
		by country: gen long newcases = confirmed - confirmed[_n - 1]
		gen byte eu = strpos("$EU", country) > 0


		// prepare for setting time series.
		// remove zero values, not striclty needed but helpful for graphing & listing
		sort country date
		drop if confirmed < 1
		by country: gen int days = _n

		encode country, 	gen(_country)

		tsset _country date
	}
	save covid, replace

end // readgithub


capture program drop pop_data
program pop_data
	
	import fred POPTOTDEA647NWDB POPTOTFRA647NWDB POPTOTITA647NWDB, aggregate(annual,eop) clear

end // pop_data


capture program drop reformat
program reformat
	syntax name
	rename v4 longitude
	// cleanup naming - shrink these overly long names
	rename country 	country
	rename province	province
	format %-20s country province
	reshape long v, i(province country lat longitude) j(date)
	rename v `namelist'
	replace date = date - 5
	recast  long date
	replace date = date + td(22jan2020)
	format %td date
end // reformat



