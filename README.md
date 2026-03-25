# EC338 - Sibling Gender Composition in Flanders

This repository is a replication package for an economics project on sibling gender composition and academic achievement among adolescents in Flanders, Belgium, using HBSC repeated cross-section data.

## How to Replicate

- Software: Stata 18
- Command: `do code/master.do`
- Input data: place HBSC wave files in `data/raw/`
- Outputs: generated datasets, tables, figures, and logs are written to `data/` and `output/`

Run the full project from the repository root in Stata:

```stata
do code/master.do
```

## Project Overview

- Builds a harmonised pooled dataset from the raw HBSC waves
- Constructs sibling composition indicators and analysis samples
- Estimates ordered probit and OLS specifications for the main results
- Exports publication tables and the final write-up assets

## Data and Paper Assets

- `data/raw/`: local-only raw HBSC inputs
- `data/interim/`: intermediate cleaned wave files
- `data/final/`: final pooled analysis dataset
- `paper/`: manuscript source and Overleaf assets

See [data/README.md](/Users/aarushbathula/Developer/modules/ec338-hbsc-belgium-flemish/data/README.md) and [output/README.md](/Users/aarushbathula/Developer/modules/ec338-hbsc-belgium-flemish/output/README.md) for the local file conventions.

## Software and Dependencies

- Stata 18
- User-written Stata packages: `estout`
- The scripts use repo-relative paths instead of a machine-specific absolute path

## Outputs

After a successful run you should expect:

- `data/final/hbsc_pooled_BEFL_final.dta`
- `output/tables/table1_grouped.tex`
- `output/tables/table2_balance.tex`
- `output/tables/table3_main_results.tex`
- `output/tables/table4_marginal_effects.tex`
- `output/tables/table5_heterogeneity.tex`
- `output/tables/table6_composition.tex`
- `output/tables/table7_wave2014.tex`
- `output/tables/table8_comp_age.tex`
- `output/tables/table9_2014_full.tex`
- `output/logs/master.log`

## PROJECT_STATUS

- Replication workflow: ready
- Data availability: local-only
- Paper assets: included
- Known gaps: full replication depends on local HBSC wave files and a Stata environment with the required user-written package

## Limitations

- The raw HBSC `.dta` files are not distributed through this repository
- Full replication depends on local access to the wave files and a matching Stata setup
- Archived do-files are preserved for provenance, but only the active pipeline is maintained as the intended workflow
