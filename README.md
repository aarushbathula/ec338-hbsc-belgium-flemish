# EC338 HBSC Project — Belgium (Flemish)

This repository contains the reproducible workflow for **Warwick EC338 Assignment 1** (Group T), using the *Health Behaviour in School-aged Children (HBSC)* international dataset.
The project focuses on the **Belgium (Flemish)** subsample across the **2006**, **2010**, and **2014** survey waves.

---

## 📂 Repository structure

```text
ec338-hbsc-belgium-flemish/
├── code/                  # Stata scripts (.do files)
│   ├── 01_data_build.do       # Pools HBSC 2006/2010/2014, filters to Belgium–Flemish
│   ├── 02_analysis.do         # (to be added) analysis + regression
│   └── 03_tables_figs.do      # (to be added) export tables/figures
│
├── data/
│   ├── raw/              # Raw HBSC .dta files (not tracked in Git)
│   ├── interim/          # Temporary per-wave datasets
│   └── final/            # Final pooled dataset (output)
│
├── output/
│   ├── logs/             # Build and analysis logs
│   ├── tables/           # Regression and summary tables
│   └── figures/          # Figures (if used)
│
├── paper/                # LaTeX write-up and compiled PDF
├── .gitignore
└── README.md
```

---

## Project description

The Health Behaviour in School-aged Children (HBSC) study is a cross-national research project conducted in collaboration with the World Health Organization (WHO). It collects data every four years on the health, well-being, social environments, and health behaviours of adolescents aged 11, 13, and 15 years.

This project aims to:

- Pool data from the 2006, 2010, and 2014 HBSC waves.
- Filter the dataset to focus on the Belgium (Flemish) region.
- Conduct descriptive and regression analyses on health outcomes.
- Produce tables and figures summarizing key findings.

---

## Getting started

### Prerequisites

- Stata 15 or higher (for running `.do` scripts)
- LaTeX distribution (for compiling the paper)
- Git (for version control)

### Setup

1. Clone the repository:

   ```bash
   git clone https://github.com/yourusername/ec338-hbsc-belgium-flemish.git
   cd ec338-hbsc-belgium-flemish
   ```

2. Download the raw HBSC `.dta` files for 2006, 2010, and 2014 and place them in `data/raw/`.

3. Run the data build script:

   ```stata
   do code/01_data_build.do
   ```

4. (To be added) Run analysis and tables scripts when ready.

---

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

---

## Acknowledgments

HBSC data © WHO Collaborating Centre for International Health Behaviour in School-aged Children.
