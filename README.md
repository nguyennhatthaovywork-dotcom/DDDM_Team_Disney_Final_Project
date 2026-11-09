# Predicting HDB Resale Flat Prices to Support Property Pricing Decisions in Singapore

**Data-Driven Decision Making (DDDM) — Team Disney | VNUK Final Project 2026**

## 1. Project overview

This project analyses Singapore Housing & Development Board (HDB) resale transactions and develops a **Linear Regression** model to support property pricing decisions. The workflow combines historical data analysis, data-quality assessment, feature preparation, model training and validation, out-of-time testing, MySQL result storage, and interactive Tableau dashboards.

**Required project pipeline:** Dataset → MySQL → KNIME (data quality, preparation, EDA and machine learning) → MySQL (results) → Tableau → Decision recommendations.

The model provides decision-support estimates, **not definitive property valuations**.

## 2. Decision questions

The project follows the three questions established in Week 1:

- **DQ1 — UNDERSTAND:** How do HDB resale prices vary across towns, flat types, floor areas and transaction periods?
- **DQ2 — PREDICT:** How accurately can HDB resale flat prices be predicted using property characteristics available before a pricing decision?
- **DQ3 — DECIDE:** How can predicted resale prices and historical transaction patterns support property pricing recommendations across different flat types and towns?

## 3. Data source, licence and study period

**Original publisher:** Housing & Development Board (HDB), Singapore.

**Official dataset:** [Resale flat prices based on registration date from Jan-2017 onwards](https://data.gov.sg/datasets/d_8b84c4ee58e3cfc0ece0d773c8ca6abc/view), published on data.gov.sg.

**Licence:** [Singapore Open Data Licence](https://data.gov.sg/open-data-licence). The licence permits copying, adaptation and distribution, subject to its conditions, including source attribution. HDB does not endorse this project.

**Dataset attribution:** This project contains information from HDB's *Resale flat prices based on registration date from Jan-2017 onwards*, made available through data.gov.sg under the Singapore Open Data Licence. Source: https://data.gov.sg/datasets/d_8b84c4ee58e3cfc0ece0d773c8ca6abc/view; licence: https://data.gov.sg/open-data-licence.

The public dataset is updated over time. **This project uses fixed historical subsets ending in June 2026**; newer records published on data.gov.sg are **not** included in the reported results.

| Dataset / stage | Period | Records | Purpose |
|---|---|---:|---|
| Historical source | Jan 2024–Dec 2025 | 52,916 | Data-quality assessment and historical analysis |
| Combined project source | Jan 2024–Jun 2026 | 65,142 | Includes later independent-test records |
| Model-candidate training subset | 2024 | 27,349 | Linear Regression training |
| Model-candidate validation subset | 2025 | 24,286 | Model evaluation and baseline comparison |
| Independent test | Jan–Jun 2026 | 12,226 | Out-of-time evaluation |

The 2024–2025 source comprises **27,832** records from 2024 and **25,084** from 2025. Following the Week 2 quality-assessment and review-selection process, **51,635** records were designated model candidates and **1,281** records were flagged for further review. The original records were preserved; quality flags do not automatically prove that a record is erroneous.

The original HDB source contains 11 fields: `month`, `town`, `flat_type`, `block`, `street_name`, `storey_range`, `floor_area_sqm`, `flat_model`, `lease_commence_date`, `remaining_lease` and `resale_price`. In MySQL, `transaction_id` is an additional generated row identifier, **not an HDB source field**.

## 4. Tools and methodology

- **MySQL / MySQL Workbench:** Store raw HDB data, perform SQL quality checks and aggregations, and retain data-quality summaries and model outputs.
- **KNIME Analytics Platform:** Perform data preparation, categorical encoding, Linear Regression, prediction, evaluation and write-back to MySQL. The workflow includes One to Many (PMML), PMML Transformation Apply, Regression Predictor, Numeric Scorer and database-writing nodes.
- **Tableau:** Explore historical prices, prediction accuracy, error patterns, empirical price-range coverage and segment-level insights using interactive dashboards.

The modelling approach uses a **chronological split**: 2024 for training, 2025 for validation, and January–June 2026 for independent testing. The 2026 test data was not used to train the model. Features that directly reveal the target, such as `price_per_sqm` derived from actual `resale_price`, are excluded from model training; `transaction_id` is used for tracking rather than as a predictor.

### Week 2 data-quality checks

1. Missing Values
2. Duplicate Records
3. Invalid Values
4. Inconsistent Values
5. Outliers

For the 52,916-record historical dataset, checks identified **0 missing source-field values**, **27 duplicate groups** comprising **28 extra identical rows** (55 flagged participating rows), **0 invalid values under the documented rules**, **1 lease-related inconsistency requiring verification**, **132 floor-area outlier flags** and **1,124 resale-price outlier flags**. Flags can overlap; do not add individual flag counts to estimate the number of review records. The raw data was not automatically corrected or deleted.

## 5. Main model results

| Metric | Validation 2025 | Independent test Jan–Jun 2026 |
|---|---:|---:|
| Transactions | 24,286 | 12,226 |
| Linear Regression MAE | SGD 54,923.05 | SGD 59,316.49 |
| Linear Regression RMSE | SGD 72,639.19 | SGD 88,412.19 |
| R² | 0.830 | Not reported |
| Underprediction rate | 74.49% | 63.88% |

For 2025 validation, the **Town-and-Flat-Type Median Baseline** produced **MAE = SGD 76,260.78** and **RMSE = SGD 110,101.59**. Linear Regression reduced validation MAE by approximately **28%** relative to this selected baseline. See the exported KNIME workflow and the model-comparison results for the implementation and per-record evidence.

The project derives an empirical error margin of **±SGD 117,547.79** from the 90th percentile of 2025 validation absolute errors. On the 2026 independent test, the associated fixed-width estimated price ranges covered **10,801 of 12,226** actual transactions, or **88.34%**. This is below the 90% reference target and is **not a guaranteed 90% statistical prediction interval**.

Residuals / signed errors are defined as **actual price − predicted price**. Positive values indicate underprediction. The 2026 overall mean signed error was **+SGD 32,699.72**. These are retrospective evaluation results, not promises of future accuracy.

## 6. Decision recommendations

1. **Model-assisted pricing:** Use Linear Regression estimates as a starting point alongside comparable historical transactions from similar towns, flat types and property characteristics.
2. **Uncertainty-aware communication:** Show an empirical price range alongside each point prediction and explain the limitations of a fixed error margin.
3. **Risk-based manual review:** Prioritise checks for towns and flat types with higher prediction errors, systematic bias or lower range coverage; interpret results cautiously where sample sizes are small.

These recommendations support pricing decisions but do not replace professional judgement.

## 7. Repository structure

The folders below are placed **directly at the root of this GitHub repository** (there is no additional `DDDM_Team_Disney_Final_Submission` wrapper folder on GitHub).

```text
DDDM_Team_Disney_Final_Project/
├── README.md
├── 01_Dataset_and_SQL/
│   ├── DDDM_HDB_Final_Project.sql
│   ├── Singapore_HDB_Resale_2024_to_2025.xlsx
│   ├── HDB_Resale_2024_to_Jun2026.csv
│   └── Model_Ready_Datasets/
│       └── hdb_resale_model_candidate_2024_2025.csv
├── 02_KNIME_Workflows/
│   ├── DDDM_HDB_Week2.knwf
│   ├── DDDM_HDB_Week3.knwf
│   └── DDDM_HDB_Week3_Final_Demo.knwf
├── 03_Tableau_Dashboard/
│   └── Disney_HDB_Price_Prediction_Dashboard_W3.twbx
├── 04_Evidence_and_Figures/
│   ├── DQ1_Understand/
│   ├── DQ2_Predict/
│   └── DQ3_Decide/
└── 05_Final_Report/
    └── Final_Report.pdf
```

Paths shown above are relative to the repository root. Refer to the file listing for exact filenames; evidence image filenames may vary across downloads.

## 8. How to inspect and reproduce the project

### Prerequisites

- MySQL Server and MySQL Workbench, with permission to create a database and tables.
- KNIME Analytics Platform with the extensions/nodes required by the exported workflows, including MySQL/database connectivity and PMML-related transformation nodes.
- Tableau Desktop or compatible software for opening the `.twbx` workbook.
- The files in this repository, plus a working local data-source and database configuration.

**Environment setup:** Use compatible versions of the applications above and install any missing KNIME extensions when prompted. Configure database credentials, local file paths and data-source connections on the reviewer's own machine; do not commit passwords or access tokens to the repository.

### A. Inspect or prepare MySQL

1. Download or clone the repository. Open `01_Dataset_and_SQL/DDDM_HDB_Final_Project.sql` in MySQL Workbench.
2. Use a local database named `dddm_hdb`. The historical source data should populate `hdb_resale_raw` with the 11 HDB attributes plus a MySQL-generated `transaction_id`.
3. If importing the `.xlsx` historical source, convert/import it using a supported MySQL-compatible format while preserving field types and values. For CSV files, confirm the actual delimiter, encoding and date/number formats before import.
4. **Do not execute the entire SQL script blindly.** It contains a mixture of schema-related statements and analytical queries; some outputs also depend on KNIME execution. Check each section, creation order, destination tables and any database-dependent statements before running them.
5. To inspect an already populated project database without changing data, run:

```sql
USE dddm_hdb;
SHOW TABLES;
SELECT COUNT(*) AS historical_records FROM hdb_resale_raw;
SELECT COUNT(*) AS validation_rows FROM hdb_resale_predictions_w3_2025;
SELECT COUNT(*) AS test_rows FROM hdb_resale_predictions_w4_2026;
```

Expected counts in the completed project database are **52,916**, **24,286** and **12,226**, respectively. A fresh database will not necessarily contain the derived tables until the relevant KNIME write-back steps have been executed.

### B. Inspect or run KNIME workflows

1. Import `02_KNIME_Workflows/DDDM_HDB_Week2.knwf`, `DDDM_HDB_Week3.knwf` and `DDDM_HDB_Week3_Final_Demo.knwf` into KNIME.
2. Check **input file paths** and **CSV Reader** settings in the modelling/demo workflow. Check the **MySQL connectors** and database-reading nodes in the Week 2 workflow; update host, port, schema and credentials for the local MySQL instance.
3. Inspect the Week 2 quality-check and preparation steps, then the Week 3 training/2025 validation stages and the January–June 2026 test stages.
4. Inspect the baseline's GroupBy and Joiner branches, confirm which period supplies the reference medians, and check that fitted transformations are applied consistently to validation and test data. Verify row counts and the intended `resale_price` target before execution.
5. **Before running any DB Writer node**, check its target table and write mode. Running the final demo or executing all nodes indiscriminately may overwrite results already stored in MySQL.

Some `.knwf` exports preserve executed node states, but this does not guarantee that their external source files, local paths or database connections work unchanged on a different computer. The final-demo workflow is for inspecting/demonstrating the model; it does not replace the Week 2 MySQL integration workflow.

### C. Inspect Tableau

1. Open `03_Tableau_Dashboard/Disney_HDB_Price_Prediction_Dashboard_W3.twbx` in Tableau.
2. If prompted, configure the relevant MySQL connection to `dddm_hdb`. A packaged `.twbx` file does not automatically guarantee that a live database source is available to a reviewer.
3. Inspect the historical EDA, 2025 model reliability, 2026 model reliability and 2026 prediction-range views.
4. Test the interactive **Town** and **Flat Type** filters and compare overall metrics with the results listed in Section 5.

### D. Inspect supporting evidence

- `04_Evidence_and_Figures/DQ1_Understand/`: Historical price patterns, quality checks and review decisions.
- `04_Evidence_and_Figures/DQ2_Predict/`: Regression workflow, validation, baseline comparison, independent test and empirical ranges.
- `04_Evidence_and_Figures/DQ3_Decide/`: Prediction bias and coverage by property segment supporting the recommendations.

## 9. Limitations and responsible use

- Important factors such as interior condition, renovation quality and transport accessibility are not represented in the available source fields.
- Prediction performance differs across periods, towns and flat types; the independent January–June 2026 test covers six months.
- Data-quality flags and the review-selection policy can affect representation of unusual or high-priced flats. Flagged records are **not automatically errors**.
- The fixed-width empirical price ranges do not guarantee 90% coverage for individual properties or future transactions.
- Reproducing the pipeline may require matching dependencies, file formats and input paths, configuring MySQL connections, and running KNIME write-back nodes in the correct order.
- Share only authorised data, avoid committing database credentials, and acknowledge the HDB dataset, licence, academic sources and any AI-assisted contributions according to VNUK's academic-integrity rules.

The system is intended to support, not replace, professional judgement in property pricing decisions.
