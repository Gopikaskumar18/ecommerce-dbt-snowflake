-- ============================================================
-- SNOWFLAKE SETUP: Run these in Snowflake worksheet before dbt
-- ============================================================

-- 1. Create database & schemas (Raw, Staging, Marts)
CREATE DATABASE IF NOT EXISTS ECOMMERCE_DB;

CREATE SCHEMA IF NOT EXISTS ECOMMERCE_DB.RAW;
CREATE SCHEMA IF NOT EXISTS ECOMMERCE_DB.STAGING;
CREATE SCHEMA IF NOT EXISTS ECOMMERCE_DB.MARTS;

-- 2. Create warehouse
CREATE WAREHOUSE IF NOT EXISTS COMPUTE_WH
  WAREHOUSE_SIZE = 'X-SMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE;

-- 3. Create roles
CREATE ROLE IF NOT EXISTS TRANSFORMER;
GRANT USAGE ON WAREHOUSE COMPUTE_WH TO ROLE TRANSFORMER;
GRANT ALL ON DATABASE ECOMMERCE_DB TO ROLE TRANSFORMER;
GRANT ALL ON ALL SCHEMAS IN DATABASE ECOMMERCE_DB TO ROLE TRANSFORMER;
GRANT ALL ON FUTURE SCHEMAS IN DATABASE ECOMMERCE_DB TO ROLE TRANSFORMER;
GRANT ALL ON ALL TABLES IN DATABASE ECOMMERCE_DB TO ROLE TRANSFORMER;
GRANT ALL ON FUTURE TABLES IN DATABASE ECOMMERCE_DB TO ROLE TRANSFORMER;

-- 4. Raw source tables (simulate your ERP/App data landing here via COPY INTO)
CREATE OR REPLACE TABLE ECOMMERCE_DB.RAW.RAW_ORDERS (
    order_id        VARCHAR(36),
    customer_id     VARCHAR(36),
    order_date      TIMESTAMP_NTZ,
    status          VARCHAR(50),
    amount          FLOAT,
    discount        FLOAT,
    shipping_cost   FLOAT,
    product_id      VARCHAR(36),
    quantity        INT,
    _loaded_at      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

CREATE OR REPLACE TABLE ECOMMERCE_DB.RAW.RAW_CUSTOMERS (
    customer_id     VARCHAR(36),
    first_name      VARCHAR(100),
    last_name       VARCHAR(100),
    email           VARCHAR(255),
    country         VARCHAR(100),
    signup_date     DATE,
    segment         VARCHAR(50),
    _loaded_at      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

CREATE OR REPLACE TABLE ECOMMERCE_DB.RAW.RAW_PRODUCTS (
    product_id      VARCHAR(36),
    product_name    VARCHAR(255),
    category        VARCHAR(100),
    sub_category    VARCHAR(100),
    unit_price      FLOAT,
    cost_price      FLOAT,
    _loaded_at      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

CREATE OR REPLACE TABLE ECOMMERCE_DB.RAW.RAW_SESSIONS (
    session_id      VARCHAR(36),
    customer_id     VARCHAR(36),
    session_date    DATE,
    channel         VARCHAR(100),
    pages_visited   INT,
    time_on_site    INT,   -- seconds
    converted       BOOLEAN,
    _loaded_at      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- 5. Load seed data (dbt will handle this via `dbt seed`)
-- See seeds/ folder for CSV files
