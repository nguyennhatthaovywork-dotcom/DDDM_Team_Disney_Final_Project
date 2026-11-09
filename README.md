# Singapore HDB Resale Price Analysis and Decision Support

**Data-Driven Decision Making (DDDM) — Team Disney | 2026**

## 1. Project overview

This project analyses Singapore Housing & Development Board (HDB) resale transactions and develops a Linear Regression model to support resale price decisions. The workflow combines historical data analysis, data-quality checks, prediction, evaluation, and evidence-based recommendations.

The model is intended as a **decision-support tool**, not a definitive property valuation system.

## 2. Decision questions

- **DQ1 — UNDERSTAND:** What patterns in HDB resale prices can be observed across towns, flat types, floor areas and months?
- **DQ2 — PREDICT:** How accurately can a Linear Regression model estimate resale prices, and how does it perform against a simple median baseline?
- **DQ3 — DECIDE:** How can model predictions, error patterns and uncertainty inform practical pricing decisions?

## 3. Data and time-based evaluation

| Dataset / stage | Period | Number of records | Purpose |
|---|---|---:|---|
| Original historical source | Jan 2024–Dec 2025 | 52,916 | Historical analysis and quality assessment |
| Original combined source | Jan 2024–Jun 2026 | 65,142 | Source that also contains the independent 2026 period |
| Model candidate — 2024 subset | 2024 | 27,349 | Model training |
| Model candidate — 2025 subset | 2025 | 24,286 | Internal validation and baseline comparison |
| Independent test | Jan–Jun 2026 | 12,226 | Evaluation on a later, separate period |

The original 2024–2025 source consists of **27,832 records from 2024** and **25,084 records from 2025**. Following the Week 2 review/selection workflow, **51,635 records** were designated model candidates and **1,281 records** were flagged for review. Flags are not, by themselves, proof that records are erroneous.

**Important:** The 2026 observations were not used to train the model.

**Data source and sharing rights:** The original publisher, source URL, access date and applicable reuse terms must be verified and documented before the datasets are published in a public repository. The filenames alone do not establish permission to redistribute the data.

## 4. Tools and methodology

- **MySQL:** Store transaction tables, run quality-assessment queries, examine historical patterns and validate model outputs.
- **KNIME Analytics Platform:** Prepare model candidates, transform explanatory variables, fit Linear Regression, generate predictions and calculate evaluation outputs.
- **Tableau:** Present historical analysis, model reliability, prediction bias and empirical prediction ranges.

The project uses a **time-based split**: train on 2024 model-candidate records, validate on 2025 model-candidate records, and evaluate separately on Jan–Jun 2026 data. Any fitted transformation must be learned from training data and applied consistently to later periods.

### Week 2 data-quality checks

1. Missing Values
2. Duplicate Records
3. Invalid Values
4. Inconsistent Values
5. Outliers

Previously recorded results for the **52,916-row historical dataset** include no missing values in the 11 source attributes, 27 duplicate groups (28 extra identical rows), no invalid values under the documented checks, one lease-related inconsistency flagged for verification, 132 floor-area outliers and 1,124 resale-price outliers under the IQR rules. These flags can overlap and should not be summed to estimate the review count.

## 5. Main model results

| Metric | Validation 2025 | Independent test 2026 |
|---|---:|---:|
| Transactions | 24,286 | 12,226 |
| Linear Regression MAE | SGD 54,923.05 | SGD 59,316.49 |
| Linear Regression RMSE | SGD 72,639.19 | SGD 88,412.19 |
| R² | 0.83 | Not reported here |
| Underprediction rate | 74.49% | 63.88% |

On the **2025 validation period**, the Town-and-Flat-Type Median Baseline had an MAE of **SGD 76,260.78**, compared with **SGD 54,923.05** for Linear Regression (approximately **28% lower MAE**).

The project also uses a fixed empirical error margin of **±SGD 117,547.79**, derived from the 90th percentile of absolute errors on the 2025 validation data. On the independent 2026 test, the resulting estimated ranges achieved **88.34% empirical coverage**. This is below the 90% reference target; the ranges are **not guaranteed 90% statistical prediction intervals** for individual transactions.

These are retrospective evaluation results, not a guarantee of future performance.

## 6. Decision recommendations

1. **Model-based pricing support:** Use the Linear Regression estimate as a starting point alongside comparable historical transactions, rather than as an automatic final price.
2. **Uncertainty-aware pricing:** Present a price range with the point estimate and clearly explain the empirical, fixed-margin approach and its limitations.
3. **Risk-based manual review:** Prioritise checks for towns and flat types showing larger prediction errors or weaker empirical coverage. Subgroup estimates based on smaller sample sizes should be interpreted cautiously.

The full supporting evidence and interpretation belong in the final report and the figures in `04_Evidence_and_Figures`.

## 7. Repository structure

```text
DDDM_Team_Disney_Final_Submission/
├── 01_Dataset_and_SQL/
│   ├── DDDM_HDB_Final_Project.sql
│   ├── Singapore_HDB_Resale_2024_to_2025(2).xlsx
│   ├── HDB_Resale_2024_to_Jun2026(1).csv
│   └── Model_Ready_Datasets/
│       └── hdb_resale_model_candidate_2024_2025(1).csv
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
├── 05_Final_Report/
└── README.md
```

Some evidence files may have different local suffixes if the original files were downloaded more than once. Check actual filenames before using paths in instructions or links.

## 8. How to inspect and reproduce the project

### A. Inspect historical data and SQL

1. Open `01_Dataset_and_SQL/DDDM_HDB_Final_Project.sql` in MySQL Workbench.
2. Use a MySQL database named `dddm_hdb` and import the historical records to `hdb_resale_raw`, with the expected source schema and a MySQL-generated `transaction_id`.
3. Execute only the relevant statements for the intended step. **Do not execute the entire SQL file blindly**: the script contains database/table definitions and view-creation statements as well as read-only queries.
4. For evidence-only inspection, use the documented `SELECT` queries and review existing Week 2 summary and model-evaluation tables.

**Reproducibility note:** The SQL file does not, by itself, guarantee that every derived database table or view will exist in a fresh database. Some outputs are created by the KNIME workflows; their dependencies and load order must be checked.

### B. Inspect or run KNIME workflows

1. Import the `.knwf` files from `02_KNIME_Workflows` into KNIME Analytics Platform.
2. Inspect file-reader settings, input paths, MySQL connections and required extensions; change local machine-specific paths and credentials as needed.
3. Inspect the Week 2 data-quality and preparation logic, then the Week 3 training/validation and independent 2026 evaluation steps.
4. Run only after verifying source files, transformation consistency and database destinations. The `Final_Demo` workflow is intended as a separate demo version; verify its DB Writer destinations before executing to avoid overwriting final tables.

Exported KNIME files may preserve executed node states, but their presence does not guarantee that all external resources are bundled or that the workflow can be executed unchanged on another computer.

### C. Open Tableau

Open `03_Tableau_Dashboard/Disney_HDB_Price_Prediction_Dashboard_W3.twbx` in Tableau. The workbook may require access to the `dddm_hdb` MySQL database, because a `.twbx` file does not necessarily include a usable extract for a live database connection. Check the data-source connections and update them if necessary.

### D. Verify the evidence

- `DQ1_Understand`: source overview, five data-quality checks, quality summary and historical price dashboard.
- `DQ2_Predict`: regression workflow, 2025 validation, baseline comparison, independent 2026 test and empirical prediction ranges.
- `DQ3_Decide`: prediction bias and coverage by town/flat type, supporting the three decision recommendations.

## 9. Limitations and publication checklist

- Confirm original dataset attribution, licensing and redistributability before changing the repository visibility to public.
- Review all SQL files, workflow settings and data-source connections for passwords, tokens and private machine paths before publishing.
- Check that the historical input data and cleaned/model-candidate outputs are traceable to the same processing decisions; do not silently change raw values to force alignment.
- Confirm source-file parsing details, including the CSV delimiter and any date-format differences.
- Confirm that the uploaded Tableau package can open with its intended data source and that the final report has the required instructor-approved format.
- Model predictions, fixed-width empirical ranges and subgroup-based review priorities are decision aids, not confirmed commercial outcomes or definitive valuations.

