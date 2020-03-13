// Module to import COVID-19 data from Github
// Koenraad Blot updated 13MAR2020

global EU "Spain Portugal France Belgium Netherlands Denmark Sweden Norway Finland Germany Ireland UK Hungary Slovakia Slovenia Austria Poland Romania Malta Luxembourg Italy Croatia Latvia Greece Czech Republic Bosnia and Herzegovina Estonia"
capture program drop covid
program covid
	// change this to where you keep the covid.dta file
	cd ~/Documents
	capture use covid, clear
	if ! _rc {
		// the file exists and has been read into memory. 
		// Check last date - if up to date, do not read from the online source
		qui summarize date 
		local lastdate = r(max)
		local today = td($S_DATE)
		// if the file is more than 1 day old, re-read the online data source
		if `lastdate' < `today' - 1 {
			readgithub
		}
	}
	else {
		// the file is not found, so read it online
		readgithub
	}
	// The covid.dta file is now saved in ~/Documents, run the graphics
	covid_gr
end // covid

capture program drop reformat
program reformat
	syntax name
	rename v4 longitude
	reshape long v, i(provincestate countryregion lat longitude) j(date)
	rename v `namelist'
	replace date = date - 5
	recast  long date
	replace date = date + td(22jan2020)
	format %td date
end // reformat


capture program drop covid_gr
program covid_gr
	use covid, clear
	collapse (sum) confirmed deaths recovered active, by(country date)
	sort country date
	by country: gen long newcases = confirmed - confirmed[_n - 1]
	gen byte eu = strpos("$EU", country) > 0
	

	foreach country in China Italy Iran US France Germnay Spain Belgium {
		preserve
		qui keep if country == "`country'" & confirmed > 0
		twoway 	(tsline confirmed, recast(connected)) ///
					(tsline recovered, recast(connected)) ///
					(tsline active, recast(connected)) ///
					(tsline deaths, recast(connected) yaxis(2)) ///
					, ///
					title(`country', size(small)) name(`country', replace)
		twoway	(tsline newcases, recast(bar)), title("`country' new cases", size(small)) name(`country'_new, replace)
		restore	
	}
end // covid_gr





capture program drop readgithub
program readgithub
	di "*** reading from Github ***"
	quietly {
		local githubroot = "https://raw.githubusercontent.com/CSSEGISandData/COVID-19/master/csse_covid_19_data/csse_covid_19_time_series"
		tempfile confirmed deaths recovered	
		
		import delimited "`githubroot'/time_series_19-covid-Confirmed.csv", bindquote(strict) clear
		reformat confirmed
		save `confirmed'
		save confirmed, replace
		import delimited "`githubroot'/time_series_19-covid-Deaths.csv", bindquote(strict) clear
		reformat deaths
		save `deaths'

		import delimited "`githubroot'/time_series_19-covid-Recovered.csv", bindquote(strict) clear
		reformat recovered
		save `recovered'

		use `confirmed', clear
		merge 1:1 countryregion provincestate date using `deaths', keepusing(deaths) gen(_deaths)
		merge 1:1 countryregion provincestate date using `recovered', keepusing(recovered) gen(_recovered)
		gen long active = confirmed - deaths - recovered
		format %-20s countryregion provincestate
		replace provincestate = "." if provincestate == ""
		// The US data have doubles! Listing is for cities within states, then for states too.
		drop if countryregion == "US" & strpos(provincestate, ", ")
		encode countryregion, gen(country)
		encode provincestate, gen(province)
		egen place = group(country province)
		drop _* country province // provincestate
		rename countryregion country

		tsset place date
	}
	save covid, replace

end // readgithub