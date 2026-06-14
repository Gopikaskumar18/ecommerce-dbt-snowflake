# E-Commerce Analytics — dbt + Snowflake Pipeline

End-to-end ELT pipeline using **dbt Core** and **Snowflake** with a 3-layer architecture (Raw → Staging → Marts). Processes **155K+ rows** across 4 source tables into business-ready gold layer marts.

## Architecture

```
Raw Layer (Snowflake)           Staging Layer (dbt views)       Marts Layer (dbt tables)
──────────────────────          ──────────────────────────      ────────────────────────
RAW_ORDERS   (50K rows) ──────► stg_orders          ──────────► mart_customer_360
RAW_CUSTOMERS (5K rows) ──────► stg_customers       ──────────► mart_revenue
RAW_PRODUCTS  (200 rows)──────► stg_products        ──────────► mart_channel_attribution
RAW_SESSIONS (100K rows)──────► stg_sessions        ──────────► mart_orders_incremental
```

## Models

| Model | Type | Rows | Description |
|-------|------|------|-------------|
| `stg_orders` | View | 50K | Cleaned orders with financial calculations |
| `stg_customers` | View | 5K | Normalized customers with tenure metrics |
| `stg_products` | View | 200 | Products with margin % and price tier |
| `stg_sessions` | View | 100K | Sessions with channel grouping and bounce logic |
| `mart_customer_360` | Table | 5K | LTV, RFM scores, churn risk per customer |
| `mart_revenue` | Table | ~1.8K | Daily revenue fact by category, country, segment |
| `mart_channel_attribution` | Table | 6 rows | First-touch attribution with LTV by channel |
| `mart_orders_incremental` | Incremental | 50K | Incremental load — 20x faster than full refresh |

## Performance

- Staging views: sub-second (no storage cost, always fresh)
- Mart full refresh: ~3 sec on X-Small warehouse
- Incremental run (new rows only): ~0.4 sec vs 8 sec full refresh
- Cluster keys on `(order_month, category)` and `(customer_segment, churn_risk)` reduce bytes scanned ~60% on typical dashboard queries

See [`PERFORMANCE.md`](./PERFORMANCE.md) for full benchmark breakdown.

## Tech Stack

- **Snowflake** — Raw, Staging, Marts schemas
- **dbt Core** — transformations, tests, documentation, lineage graph
- **dbt-utils** — date spine, surrogate keys
- **dbt-expectations** — data quality tests
- **Python + Faker** — seed data generation (155K rows across 4 CSVs)

## Setup

**1. Snowflake**
```sql
-- Run sql/01_snowflake_setup.sql in your Snowflake worksheet
```

**2. Environment variables**
```bash
export SNOWFLAKE_ACCOUNT="your-account"
export SNOWFLAKE_USER="your-user"
export SNOWFLAKE_PASSWORD="your-password"
```

**3. Install dbt**
```bash
pip install dbt-snowflake
cp profiles.yml ~/.dbt/profiles.yml
dbt deps
```

**4. Run**
```bash
dbt seed    # Load CSVs → Snowflake
dbt run     # Build all models
dbt test    # Run 15+ data quality tests
dbt docs generate && dbt docs serve   # Lineage graph at localhost:8080
```

## Data Tests

- `unique` + `not_null` on all primary keys
- `accepted_values` on status, segment, churn_risk fields
- Referential integrity between orders and customers
- Custom: `net_amount` ≤ `gross_amount` on every row



## Project Structure

```
├── models/
│   ├── staging/        # stg_orders, stg_customers, stg_products, stg_sessions
│   └── marts/          # mart_customer_360, mart_revenue, mart_channel_attribution,
│                       # mart_orders_incremental
├── seeds/              # 155K rows across 4 CSVs
├── macros/             # safe_divide, generate_date_spine, cents_to_dollars
├── analyses/           # cohort_retention.sql
├── sql/                # Snowflake DDL setup
├── dbt_project.yml
├── packages.yml
└── profiles.yml
```

### dbt test — 18/18 tests passing
![dbt test](screenshots/dbt_run.png)

### Lineage Graph
![Lineage Graph](screenshots/lineage_graph.png)


