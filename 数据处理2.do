**********************************处理收盘数据
clear all
cd "C:\Users\Lawrence Arendt\Desktop\债价延迟与ESG公布.revised"
use "2018收盘.dta"
*****处理日期
replace Date = dofc(Date)
format Date %td
*****按照财报日期构造指示变量，为merge做准备
gen indicator = 1 if Date >= mdy(1, 1, year(Date)) & Date <= mdy(3, 31, year(Date))
replace indicator = 2 if Date > mdy(3, 31, year(Date)) & Date <= mdy(6, 30, year(Date))
replace indicator = 3 if Date > mdy(6, 30, year(Date)) & Date <= mdy(9, 30, year(Date))
replace indicator = 4 if Date > mdy(9, 30, year(Date)) & Date <= mdy(12, 31, year(Date))
****填充trade_code
bysort bclc (Date): replace trade_code = trade_code[_n+1] if missing(trade_code)
sort trade_code Date
drop if missing(trade_code)
tostring trade_code, replace
**********************************处理财报数据
clear all
cd "C:\Users\Lawrence Arendt\Desktop\债价延迟与ESG公布.revised"
use "2018财报.dta"
*****处理日期
replace Date = dofc(Date)
format Date %td
****填充trade_code
destring(trade_code), replace force
autofill trade_code, backward
tostring trade_code, replace
sort trade_code Date
drop if missing(trade_code)
*****按照财报日期构造指示变量，为merge做准备
gen indicator = 1 if Date == date("31dec2017", "DMY")
replace indicator = 2 if Date == date("31mar2018", "DMY")
replace indicator = 3 if Date == date("30jun2018", "DMY")
replace indicator = 4 if Date == date("30sep2018", "DMY")
***********************************合并收盘与财报数据，清洗与合并市场信息
clear all
cd "C:\Users\Lawrence Arendt\Desktop\债价延迟与ESG公布.revised"
use "2018收盘.dta"
order trade_code Date
merge m:m trade_code indicator using 2018财报.dta 
drop _merge
merge m:m Date using 二维数据_中债综合指数_1.dta
drop if missing(trade_code)
drop _merge

gen year = year(Date)
drop if year == 2017
gen ESG = 0 
replace ESG = 1 if Date > date("30jun2015", "DMY") 
replace industry_nc = "1" if industry_nc == "交通运输、仓储和邮政业"
replace industry_nc = "2" if industry_nc == "信息传输、软件和信息技术服务业"
replace industry_nc = "3" if industry_nc == "制造业"
replace industry_nc = "4" if industry_nc == "建筑业"
replace industry_nc = "5" if industry_nc == "房地产业"
replace industry_nc = "6" if industry_nc == "批发和零售业"
replace industry_nc = "7" if industry_nc == "水利、环境和公共设施管理业"
replace industry_nc = "8" if industry_nc == "电力、热力、燃气及水生产和供应业"
replace industry_nc = "9" if industry_nc == "租赁和商务服务业"
replace industry_nc = "10" if industry_nc == "采矿业"
replace industry_nc = "11" if industry_nc == "金融业"
replace industry_nc = "12" if industry_nc == "居民服务、修理和其他服务业"
replace industry_nc = "13" if industry_nc == "农、林、牧、渔业"
destring industry_nc, replace
sort trade_code Date
destring(market_dirtyprice), replace
********************************************上市日期清洗
clear all
cd "C:\Users\Lawrence Arendt\Desktop\债价延迟与ESG公布.revised"
use "上市日期.dta"
destring bclc, replace force
tostring bclc, replace
******************************************合并每一年的表
clear all
cd "C:\Users\Lawrence Arendt\Desktop\债价延迟与ESG公布.revised"
use "无年份合并.dta"
append using 2015合并
append using 2016合并
append using 2018合并
append using 2019合并
append using 2020合并
****下面合并上市日期
merge m:m bclc using 上市日期.dta
drop _merge
drop if missing(trade_code)
****接下来处理变量
destring trade_code, replace force
duplicates drop trade_code Date, force
sort trade_code Date
xtset trade_code Date
gen Size = ln(tot_assets+1)
gen Lev = debttoassets
gen ROA = roa
gen ROE = roe
gen Growth = (oper_rev - L.oper_rev)/L.oper_rev
gen ListAge = ln(2024 - year(date(ipo_date,"DMY")) + 1)
gen PFixA = ln(stmnote_assetdetail_4/employee)
gen Cash = operatecashflow_ttm2/tot_cur_liab
gen Boardscale = ln(employee_board)
rename industry_nc Industry
***接下来构造滞后变量
gen Return = (dirtyprice - L7.dirtyprice)/L7.dirtyprice
gen MarketReturn = (market_dirtyprice - L7.market_dirtyprice)/L7.market_dirtyprice
gen lag1_MarketReturn = l7.MarketReturn
gen lag2_MarketReturn = l14.MarketReturn
gen lag3_MarketReturn = l21.MarketReturn
gen lag4_MarketReturn = l28.MarketReturn
***分组回归计算Delay
xtset trade_code Date
sort trade_code Date
bysort trade_code: asreg Return MarketReturn lag1_MarketReturn lag2_MarketReturn lag3_MarketReturn lag4_MarketReturn, window(Date -10 10) by(trade_code) 
rename _R2 withlag_R2
drop _Nobs _adjR2 _b_lag1_MarketReturn _b_lag2_MarketReturn _b_MarketReturn _b_lag3_MarketReturn _b_lag4_MarketReturn _b_cons
bysort trade_code: asreg Return MarketReturn, window(Date -10 10) by(trade_code)
rename _R2 nonlag_R2
drop _Nobs _adjR2  _b_MarketReturn _b_cons
gen Delay = 1 - nonlag_R2/withlag_R2
***********************************************主回归双重差分
clear all
cd "C:\Users\Lawrence Arendt\Desktop\债价延迟与ESG公布.revised"
use "回归主数据.dta"
xtset trade_code Date
sort trade_code Date
global 控制变量 "Size Lev ROA ROE Growth ListAge PFixA Cash Boardscale Industry"
***删除离群值
egen meanVar = mean(Delay)
egen sdVar = sd(Delay)
gen zVar = (Delay - meanVar) / sdVar
drop if zVar > 3 | zVar < -3
***描述性统计
logout,save(Descriptive Statistics) word replace:tabstat Delay ESG $控制变量 , stat(n mean sd p50 min max ) c(s) f(%10.3f)
***双重差分
xtset trade_code Date
gen midyear = 0
replace midyear = 1 if Date > mdy(6, 30, year(Date))
gen did = ESG * midyear

reghdfe Delay ESG midyear, absorb(trade_code year) vce(cluster trade_code)
outreg2 using 双重差分回归.doc,replace bdec(3) sdec(3) ctitle(Delay) e(r2_a)  addtext(Firm FE, YES,Year FE, YES) 
reghdfe Delay ESG midyear $控制变量, absorb(trade_code year) vce(cluster trade_code)
outreg2 using 双重差分回归.doc,append bdec(3) sdec(3) ctitle(Delay) e(r2_a)  addtext(Firm FE, YES,Year FE, YES) 
