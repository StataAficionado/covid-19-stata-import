// Module to import COVID-19 data from Github
// Koenraad Blot 05MAR2020

capture program drop import_covid
program import_covid
	local githubroot = "https://raw.githubusercontent.com/CSSEGISandData/COVID-19/master/csse_covid_19_data/csse_covid_19_time_series"
	tempfile confirmed deaths recovered	
	
	import delimited "`githubroot'/time_series_19-covid-Confirmed.csv", bindquote(strict) clear
	reformat confirmed
	save `confirmed'

	import delimited "`githubroot'/time_series_19-covid-Deaths.csv", bindquote(strict) clear
	reformat deaths
	save `deaths'

	import delimited "`githubroot'/time_series_19-covid-Recovered.csv", bindquote(strict) clear
	reformat recovered
	save `recovered'

	use `confirmed', clear
	merge 1:1 countryregion provincestate date using `deaths', keepusing(deaths) gen(_deaths)
	merge 1:1 countryregion provincestate date using `recovered', keepusing(recovered) gen(_recovered)
	format %-20s countryregion provincestate
	replace provincestate = "." if provincestate == ""
	encode countryregion, gen(country)
	encode provincestate, gen(province)
	egen place = group(country province)
	drop _*
	tsset place date
	save covid, replace

end // import_covid

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
