clear all
cd "C:\Users\Lawrence Arendt\Desktop\债价延迟与ESG公布.revised"
use "平行趋势检验数据.dta"
xtset trade_code Date
sort trade_code Date
global 控制变量 "Size Lev ROA ROE Growth ListAge PFixA Cash Boardscale Industry"
***虚拟变量构造
gen gap = 30
gen pre1 = 1 if Date < mdy(6, 30, year(Date)) - gap & Date >= mdy(1, 1, year(Date))
gen pre2 = 1 if Date < mdy(6, 30, year(Date)) - gap*2 & Date >= mdy(1, 1, year(Date))
gen pre3 = 1 if Date < mdy(6, 30, year(Date)) - gap*3 & Date >= mdy(1, 1, year(Date))

replace pre1 = 0 if Date >= mdy(6, 30, year(Date))-gap
replace pre2 = 0 if Date >= mdy(6, 30, year(Date))-gap*2
replace pre3 = 0 if Date >= mdy(6, 30, year(Date))-gap*3

gen post1 = 1 if Date > mdy(6, 30, year(Date))+gap-10 & Date <= mdy(12, 31, year(Date)) & ESG == 1
gen post2 = 1 if Date > mdy(6, 30, year(Date))+gap*2-10 & Date <= mdy(12, 31, year(Date)) & ESG == 1
gen post3 = 1 if Date > mdy(6, 30, year(Date))+gap*3-50 & Date <= mdy(12, 31, year(Date)) & ESG == 1
foreach var of varlist post* {
    replace `var' = 0 if missing(`var')
}
gen current = 0 
merge m:m trade_code using 披露ESG的债券.dta
replace current = 1 if Date >= mdy(6, 30, year(Date)) - gap-10 & Date <= mdy(6, 30, year(Date)) + gap+10 & _merge == 3 
***回归
reghdfe Delay pre3 pre2 pre1 current post1 post2 post3 $控制变量, absorb(trade_code year) vce(cluster trade_code)
outreg2 using 平行趋势检验.doc,replace bdec(3) sdec(3) ctitle(Delay) e(r2_a)  addtext(Firm FE, YES,Year FE, YES)
* reghdfe TFP_LP pre* current post* $控制变量 , absorb(stkcd year) vce(cluster stkcd)
***作图
coefplot, baselevels keep(pre* current post*) vertical coeflabels(pre3 = "-3" pre2 = "-2" pre1="-1" current = "0" post1 = "1" post2 = "2" post3 = "3") yline(0,lcolor(edkblue*0.8)) xline(10, lwidth(vthin) lpattern(dash) lcolor(teal)) ylabel(,labsize(*0.75)) xlabel(,labsize(*0.75)) ytitle("Delay", size(small)) xtitle("Treat", size(small)) addplot(line @b @at) ciopts(lpattern(dash) recast(rcap) msize(medium)) msymbol(circle_hollow) scheme(s1mono)