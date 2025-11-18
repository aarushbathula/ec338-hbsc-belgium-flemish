*******************************************************
* master.do – EC338 Replication Pipeline
*******************************************************

version 18
clear all
set more off

* Set root directory manually here:
global PROJ "/Users/aarushbathula/Developer/ec338-hbsc-belgium-flemish"
cd "$PROJ"

capture log close _all
log using "output/logs/master.log", replace text

do "code/01_data_build.do"
do "code/02_analysis.do"
do "code/03_tables_figs.do"

log close
*******************************************************
