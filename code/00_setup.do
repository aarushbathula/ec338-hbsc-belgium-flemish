*******************************************************
* 00_setup.do - shared project setup for the replication pipeline
*******************************************************

version 18

capture confirm global PROJ
if _rc {
    global PROJ "`c(pwd)'"
}

global RAW     "$PROJ/data/raw"
global INT     "$PROJ/data/interim"
global FINAL   "$PROJ/data/final"
global LOGS    "$PROJ/output/logs"
global TABLES  "$PROJ/output/tables"
global FIGURES "$PROJ/output/figures"

foreach dir in "$RAW" "$INT" "$FINAL" "$LOGS" "$TABLES" "$FIGURES" {
    capture mkdir "`dir'"
}

*******************************************************
* End 00_setup.do
*******************************************************
