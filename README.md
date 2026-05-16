# dbt-healthcare-revenue-cycle

A production-ready **dbt project** for healthcare revenue cycle analytics — 18 models, 86 tests, a Streamlit dashboard, and a full CI/CD pipeline. Turns raw insurance claims data into trusted KPIs for denial management, payer performance, and AR aging.

**Stack:** dbt · PostgreSQL · Python · Streamlit · Plotly · GitHub Actions

---

## Quick Start (run it locally in ~5 minutes)

### Prerequisites
- Python 3.10+
- PostgreSQL 14+ running locally (`host=127.0.0.1, port=5432, dbname=dbt, user=dbt, password=dbt`)
- Node.js (optional, for rebuilding the slide deck)

### 1. Clone and install dependencies

```bash
git clone https://github.com/hritikadoshi9/dbt-healthcare-revenue-cycle.git
cd dbt-healthcare-revenue-cycle
pip install -r requirements.txt
```

### 2. Configure dbt profile

Create `~/.dbt/profiles.yml`:

```yaml
healthcare_revenue_cycle:
  target: dev
  outputs:
    dev:
      type: postgres
      host: 127.0.0.1
      port: 5432
      dbname: dbt
      user: dbt
      password: dbt
      schema: public
      threads: 4
```

### 3. Run the full pipeline

```bash
dbt deps          # Install dbt packages (dbt_utils, dbt_expectations)
dbt seed          # Load denial code mappings + payer contracts
dbt run           # Build all 18 models
dbt test          # Run all 86 data quality tests
```

Expected output: `86 passed, 0 warnings, 0 errors`

### 4. Launch the dashboard

```bash
streamlit run dashboard.py
```

Open `http://localhost:8501` — you'll see live KPIs pulled from the marts.

---

## Why this project?

Healthcare revenue cycle management generates millions of records monthly across claims, denials, payments, and aging receivables. Most analytics teams rebuild the same dimensional models from scratch. This package provides:

- **Standardized star schema** — 4 dimension tables + 4 fact tables following healthcare data modeling best practices
- **CARC/RARC denial mapping** — 35+ denial reason codes pre-categorized into actionable groups (Eligibility, Authorization, Coding Error, etc.)
- **Configurable AR aging buckets** — Default 30/60/90/120 day thresholds, fully customizable via project variables
- **Composite KPI scoring** — Revenue health score, payer performance score, and denial impact tiers computed automatically
- **Production-grade testing** — 50+ built-in tests including custom data quality assertions

---

## Models

### Staging (`models/staging/`)

| Model | Description |
|-------|-------------|
| `stg_claims` | Cleaned claim line items with standardized codes and amounts |
| `stg_denials` | Denial records with appeal tracking flags |
| `stg_payments` | Payment/remittance records with net collection calculations |
| `stg_providers` | Provider master data with NPI and specialty |
| `stg_payers` | Payer/insurance data with contract status |
| `stg_patients` | Patient demographics with age groups and coverage flags |
| `stg_procedures` | CPT/HCPCS codes with RVU and fee schedule data |

### Dimensions (`models/dimensions/`)

| Model | Description |
|-------|-------------|
| `dim_providers` | Provider dimension with specialty classifications (Primary Care, Specialty, Surgical, Emergency, Ancillary) |
| `dim_payers` | Payer dimension with reimbursement tiers and government/commercial flags |
| `dim_procedures` | Procedure dimension with cost tiers and RVU complexity tiers |
| `dim_patients` | Patient dimension with HIPAA-safe age groups and coverage duration |

### Facts (`models/facts/`)

| Model | Description |
|-------|-------------|
| `fct_claims` | Full claim lifecycle — billed, paid, denied, outstanding amounts + collection rates + days in AR |
| `fct_denials` | Denial detail — CARC categories, appeal tracking, timing metrics, impact tiers |
| `fct_payments` | Payment detail — reimbursement rates, contract variance, payment speed |
| `fct_aging` | AR aging snapshot — configurable buckets, risk levels, outstanding balances |

### Marts (`models/marts/`)

| Model | Description |
|-------|-------------|
| `mart_denial_summary` | Monthly denial analytics by payer and category with appeal ROI |
| `mart_payer_performance` | Payer scorecard with composite performance score |
| `mart_revenue_kpis` | Provider-level revenue KPIs with health score |

---

## Installation

### 1. Add to your `packages.yml`

```yaml
packages:
  - git: "https://github.com/hritikadoshi9/dbt-healthcare-revenue-cycle.git"
    revision: v1.0.0
```

Then run:

```bash
dbt deps
```

### 2. Configure your sources

In your `dbt_project.yml`, set the schema where your raw data lives:

```yaml
vars:
  source_schema: 'raw_healthcare'
```

### 3. Map your source tables

Your raw data should match the schema defined in `models/staging/src_healthcare.yml`. If your column names differ, create adapter models in your own project that rename columns to match.

### 4. Run the package

```bash
dbt seed          # Load denial code mappings
dbt run           # Build all models
dbt test          # Run all tests
```

---

## Configuration

All configuration is done via `vars` in your `dbt_project.yml`:

```yaml
vars:
  # Schema containing raw source tables
  source_schema: 'raw_healthcare'

  # AR aging bucket thresholds (days)
  aging_buckets: [30, 60, 90, 120]

  # Override denial category mappings
  denial_category_override:
    '999': 'Custom Category'
```

---

## Key metrics computed

| Metric | Location | Description |
|--------|----------|-------------|
| **Gross Collection Rate** | `mart_revenue_kpis` | Paid / Billed × 100 |
| **Net Collection Rate** | `mart_revenue_kpis` | Paid / Allowed × 100 |
| **First Pass Resolution Rate** | `mart_revenue_kpis` | % of claims paid without any denials |
| **Clean Claim Rate** | `mart_revenue_kpis` | % of claims paid within 30 days with no denials |
| **Denial Rate** | `mart_payer_performance` | Denied claims / Total claims × 100 |
| **Appeal Overturn Rate** | `mart_denial_summary` | Overturned appeals / Total appeals × 100 |
| **Payer Performance Score** | `mart_payer_performance` | Weighted composite: collection (40%) + denial (30%) + speed (30%) |
| **Revenue Health Score** | `mart_revenue_kpis` | Weighted composite across 5 KPIs |
| **Days in AR** | `fct_claims` | Submission to first payment |
| **Contract Variance** | `fct_payments` | Actual reimbursement vs contracted rate |

---

## Supported warehouses

- ✅ Snowflake
- ✅ BigQuery
- ✅ Amazon Redshift
- ✅ PostgreSQL

The package uses `dbt.type_string()`, `dbt.type_numeric()`, and `dbt.datediff()` macros for cross-database compatibility.

---

## Testing

The package includes 50+ tests across three categories:

**Generic tests** — `not_null`, `unique`, `accepted_values` on all key columns

**Data quality tests** (`dbt_expectations`) — Range validation on financial amounts, collection rates

**Custom data tests** (`tests/`):
- `assert_paid_not_exceeding_billed` — Paid amount should not exceed billed by >5%
- `assert_service_before_submission` — Service date must precede submission date
- `assert_denial_after_submission` — Denial date must follow submission date
- `assert_denied_claims_have_denials` — Every denied claim has a denial record
- `assert_aging_only_open_claims` — AR aging only contains open receivables

---

## Dashboard

The included `dashboard.py` connects directly to the PostgreSQL marts and renders a live Streamlit dashboard with:

- **6 KPI cards** — Total Charges, Net Collections, Collection Rate, Denial Rate, AR Balance, Health Score
- **Revenue trend** — Monthly gross charges vs. net collections with collection rate overlay
- **AR aging donut** — Balance breakdown across 0-30, 31-60, 61-90, 91-120, 121+ day buckets
- **Denial analysis** — Denied amount by category (colored by appeal overturn rate) + trend over time
- **Payer performance** — Scatter plot (denial rate vs collection rate) + performance score bar chart
- **Provider leaderboard** — Sortable table with health score color coding

```bash
streamlit run dashboard.py
# → http://localhost:8501
```

---

## Project structure

```
dbt-healthcare-revenue-cycle/
├── models/
│   ├── staging/              # Raw source cleaning
│   │   ├── src_healthcare.yml
│   │   ├── stg_schema.yml
│   │   ├── stg_claims.sql
│   │   ├── stg_denials.sql
│   │   ├── stg_payments.sql
│   │   ├── stg_providers.sql
│   │   ├── stg_payers.sql
│   │   ├── stg_patients.sql
│   │   └── stg_procedures.sql
│   ├── dimensions/           # Dimension tables
│   │   ├── dim_providers.sql
│   │   ├── dim_payers.sql
│   │   ├── dim_procedures.sql
│   │   └── dim_patients.sql
│   ├── facts/                # Fact tables
│   │   ├── fct_claims.sql
│   │   ├── fct_denials.sql
│   │   ├── fct_payments.sql
│   │   └── fct_aging.sql
│   ├── marts/                # Analytics-ready marts
│   │   ├── mart_denial_summary.sql
│   │   ├── mart_payer_performance.sql
│   │   └── mart_revenue_kpis.sql
│   └── dim_fct_schema.yml
├── macros/
│   ├── calculate_collection_rate.sql
│   ├── assign_aging_bucket.sql
│   ├── safe_currency.sql
│   └── map_denial_category.sql
├── seeds/
│   ├── seed_denial_reason_codes.csv
│   └── seed_payer_contracts.csv
├── tests/
│   ├── assert_paid_not_exceeding_billed.sql
│   ├── assert_service_before_submission.sql
│   ├── assert_denial_after_submission.sql
│   ├── assert_denied_claims_have_denials.sql
│   └── assert_aging_only_open_claims.sql
├── .github/workflows/ci.yml
├── dbt_project.yml
├── packages.yml
└── README.md
```

---

## DAG (model lineage)

```
Sources (raw_healthcare)
  │
  ├── stg_claims ──────────┐
  ├── stg_denials ─────────┤
  ├── stg_payments ────────┤
  ├── stg_providers ───┐   │
  ├── stg_payers ──────┤   │
  ├── stg_patients ────┤   │
  └── stg_procedures ──┤   │
                       │   │
              dim_providers │
              dim_payers    │
              dim_patients  │
              dim_procedures│
                       │   │
                       ▼   ▼
                   fct_claims ──────► mart_revenue_kpis
                   fct_denials ────► mart_denial_summary
                   fct_payments ───► mart_payer_performance
                   fct_aging ──────► mart_revenue_kpis
```

---

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Add tests for any new models or macros
4. Run `dbt build` to verify everything passes
5. Submit a pull request

---

## License

MIT License. See [LICENSE](LICENSE) for details.

---

## About the author

**Hritika Doshi** — Data Analyst with 4+ years of experience in healthcare and financial analytics. Built this package based on real-world revenue cycle management patterns at enterprise healthcare organizations.

- [LinkedIn](https://linkedin.com/in/hritikadoshi)
- [Email](mailto:hritikadoshi365@gmail.com)
