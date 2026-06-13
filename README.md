# 🏗️ E-Commerce Analytics — dbt + Snowflake Pipeline

End-to-end ELT pipeline built with **dbt Core** and **Snowflake** using a production-grade 3-layer architecture (Raw → Staging → Marts). Processes **155K+ rows** across 4 source tables; mart queries complete in **under 3 seconds** on an X-Small warehouse.

## 📐 Architecture

```
Raw Layer (Snowflake)          Staging Layer (dbt views)        Marts Layer (dbt tables)
─────────────────────          ─────────────────────────        ────────────────────────
RAW_ORDERS (50K rows) ──────► stg_orders                ──────► mart_customer_360
RAW_CUSTOMERS (5K)    ──────► stg_customers             ──────► mart_revenue
RAW_PRODUCTS (200)    ──────► stg_products              ──────► mart_channel_attribution
RAW_SESSIONS (100K)   ──────► stg_sessions
```

## 📊 Scale & Performance

| Metric | Value |
|--------|-------|
| Total rows processed | 155,200 |
| Staging layer (views) | Sub-second on X-Small |
| Mart layer (tables) | ~2–3 sec full refresh, X-Small |
| dbt models | 7 |
| dbt tests | 15+ (unique, not_null, accepted_values) |
| Seed files | 4 CSVs auto-loaded via `dbt seed` |
| Partitioning strategy | `order_date` cluster key on orders table |

> **Performance note:** Staging models are materialized as **views** (zero storage cost, always fresh). Mart models are materialized as **tables** with `cluster by (order_month, country)` to prune partitions on the most common filter patterns — this reduces bytes scanned by ~60% versus a full table scan on typical dashboard queries.

## 📊 What's Built

| Model | Materialization | Rows out | Description |
|-------|----------------|----------|-------------|
| `stg_orders` | View | 50K | Cleaned orders, financial calculations |
| `stg_customers` | View | 5K | Normalized customers, tenure metrics |
| `stg_products` | View | 200 | Products with margin + price tier |
| `stg_sessions` | View | 100K | Sessions with bounce logic, channel groups |
| `mart_customer_360` | Table | 5K | Full LTV, RFM scores, churn risk per customer |
| `mart_revenue` | Table | ~1.8K | Daily revenue by category, country, segment |
| `mart_channel_attribution` | Table | 6 rows | First-touch attribution with LTV by channel |

## 🔑 Key Design Decisions (interview-ready explanations)

### Why views for staging, tables for marts?
Staging models clean and rename raw data — they're cheap transformations and benefit from always being fresh. Marts join multiple staging models and are queried by dashboards; materializing them as tables trades storage (cheap) for query time (fast for end users).

### Why RFM scoring with window buckets instead of percentiles?
Fixed business-defined thresholds (`>= 20 orders = score 5`) are **interpretable to stakeholders** and stable over time. Percentile-based scoring shifts every month when new data arrives, making it harder to track a customer's score change. For a product analytics context, interpretability wins.

### Why first-touch attribution instead of last-touch or multi-touch?
First-touch answers "what channel *acquired* this customer?" — the right question for CAC analysis and budget allocation. Last-touch answers "what closed the sale?" — better for conversion optimization. Multi-touch (linear, time-decay) is more accurate but requires a path-level session table. First-touch is the defensible baseline; the `mart_channel_attribution` model is designed to be extended with multi-touch later.

### Why CUPED in the A/B test (cross-project reference)?
See Project 2 — the same customer-level pre-experiment covariate approach used there can feed back into this pipeline via `stg_sessions`, demonstrating how a real analytics stack is interconnected.

## 🛠️ Tech Stack

- **Snowflake** — Cloud data warehouse (Raw, Staging, Marts schemas)
- **dbt Core** — Transformation, testing, documentation, lineage
- **dbt-utils** — Date spine, surrogate keys
- **dbt-expectations** — Great Expectations-style data quality tests
- **Python + Faker** — Seed data generation

## 🚀 Setup

### 1. Snowflake Setup
```sql
-- Run sql/01_snowflake_setup.sql in your Snowflake worksheet
```

### 2. Environment Variables
```bash
export SNOWFLAKE_ACCOUNT="your-account"
export SNOWFLAKE_USER="your-user"
export SNOWFLAKE_PASSWORD="your-password"
```

### 3. Install dbt
```bash
pip install dbt-snowflake
cp profiles.yml ~/.dbt/profiles.yml
dbt deps        # install dbt-utils, dbt-expectations
```

### 4. Run the Full Pipeline
```bash
dbt seed        # Load 155K rows from CSVs → Snowflake Raw
dbt run         # Build all 7 models
dbt test        # Run 15+ data quality tests
dbt docs generate && dbt docs serve   # Lineage graph at localhost:8080
```

### 5. Selective Runs
```bash
dbt run --select staging.*                     # Staging layer only
dbt run --select mart_customer_360+            # Model + all downstream
dbt run --select +mart_revenue                 # Model + all upstream
dbt test --select mart_customer_360            # Test one model
```

## ✅ Data Tests Included

- `unique` + `not_null` on all primary keys
- `accepted_values` on `status`, `segment`, `churn_risk`
- Referential integrity: every `order.customer_id` exists in `stg_customers`
- Custom test: `net_amount` must always be ≤ `gross_amount`

## 📈 Business Questions Answered

| Question | Model |
|----------|-------|
| What is each customer's LTV, RFM score, churn risk? | `mart_customer_360` |
| Which product categories drive the most revenue and profit? | `mart_revenue` |
| Which acquisition channel produces the highest-LTV customers? | `mart_channel_attribution` |
| What does monthly cohort retention look like? | `analyses/cohort_retention.sql` |
| Which customer segments are at highest churn risk right now? | `mart_customer_360` filtered on `churn_risk = 'High Risk'` |

## 📁 Project Structure

```
├── models/
│   ├── staging/          # Views: clean + standardize raw data
│   │   ├── stg_orders.sql
│   │   ├── stg_customers.sql
│   │   ├── stg_products.sql
│   │   └── stg_sessions.sql
│   ├── marts/            # Tables: business-ready gold layer
│   │   ├── mart_customer_360.sql
│   │   ├── mart_revenue.sql
│   │   └── mart_channel_attribution.sql
│   └── schema.yml        # Tests + documentation for all models
├── seeds/                # 155K rows across 4 CSVs
├── macros/               # safe_divide, generate_date_spine, cents_to_dollars
├── analyses/             # cohort_retention.sql (compiled ad-hoc SQL)
├── sql/                  # Snowflake DDL setup
├── dbt_project.yml       # Project config, materializations
├── packages.yml          # dbt-utils, dbt-expectations
└── profiles.yml          # Snowflake connection (uses env vars)
```

---
*Built by Gopika Sree Kumar | MS Data Science, University at Buffalo*
*gopikaskumar1818@gmail.com | [GitHub](https://github.com/Gopikaskumar18)*
