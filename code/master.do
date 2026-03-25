*******************************************************
* master.do – EC338 Replication Pipeline
*******************************************************

version 18
clear all
set more off

capture confirm global PROJ
if _rc {
    global PROJ "`c(pwd)'"
}

do "$PROJ/code/00_setup.do"
cd "$PROJ"

capture log close _all
log using "output/logs/master.log", replace text

* Run the active pipeline from the project root.
do "code/01_data_build.do"
do "code/02_analysis.do"
do "code/03_tables_figs.do"

log close
*******************************************************
