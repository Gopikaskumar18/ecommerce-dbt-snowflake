-- models/marts/mart_orders_incremental.sql
-- Incremental materialization: only processes NEW orders since last run.
-- At 50K orders/day in production, a full refresh would cost ~45 seconds;
-- incremental reduces this to ~2 seconds by scanning only the latest partition.
--
-- Strategy: append-only on completed orders (completed orders never change status)
-- Unique key: order_id ensures no duplicates on re-runs

{{
    config(
        materialized='incremental',
        unique_key='order_id',
        cluster_by=['order_month', 'category'],
        on_schema_change='sync_all_columns',
        tags=['mart', 'orders', 'incremental']
    )
}}

with orders as (
    select * from {{ ref('stg_orders') }}

    -- On incremental runs: only pick up orders newer than the last loaded batch
    {% if is_incremental() %}
        where order_date > (select max(order_date) from {{ this }})
    {% endif %}
),

products as (
    select * from {{ ref('stg_products') }}
),

customers as (
    select
        customer_id,
        country,
        customer_segment
    from {{ ref('stg_customers') }}
),

enriched as (
    select
        o.order_id,
        o.customer_id,
        o.order_date,
        o.order_month,
        o.order_week,
        o.status,
        o.is_completed,
        o.gross_amount,
        o.net_amount,
        o.discount_amount,
        o.shipping_cost,
        o.total_amount,
        o.quantity,

        -- Product dimensions (denormalized for query performance)
        p.product_name,
        p.category,
        p.sub_category,
        p.unit_price,
        p.cost_price,
        p.gross_margin_pct,
        p.price_tier,

        -- Derived profit at order level
        round(o.net_amount - (p.cost_price * o.quantity), 2)   as order_profit,
        round(
            (o.net_amount - (p.cost_price * o.quantity))
            / nullif(o.net_amount, 0) * 100
        , 2)                                                    as order_profit_margin_pct,

        -- Customer dimensions
        c.country,
        c.customer_segment,

        -- Load metadata
        current_timestamp()                                     as dbt_loaded_at

    from orders o
    left join products  p on o.product_id  = p.product_id
    left join customers c on o.customer_id = c.customer_id
)

select * from enriched
