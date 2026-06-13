-- models/marts/mart_revenue.sql
-- Gold layer: daily/monthly revenue fact table
-- Powers: revenue trend dashboards, forecasting, finance reporting
-- Scale: derived from 50K orders; ~1,800 daily-grain rows after aggregation
-- Performance: cluster on (order_month, category) — most dashboards filter
--              by month and product category; reduces bytes scanned ~60%

{{
    config(
        materialized='table',
        cluster_by=['order_month', 'category'],
        tags=['mart', 'revenue', 'daily']
    )
}}

with orders as (
    select * from {{ ref('stg_orders') }}
),

products as (
    select * from {{ ref('stg_products') }}
),

customers as (
    select * from {{ ref('stg_customers') }}
),

order_enriched as (
    select
        o.order_id,
        o.order_date,
        o.order_month,
        o.order_week,
        o.order_day_of_week,
        o.status,
        o.is_completed,
        o.gross_amount,
        o.net_amount,
        o.discount_amount,
        o.shipping_cost,
        o.total_amount,
        o.quantity,

        -- Product dimensions
        p.product_name,
        p.category,
        p.sub_category,
        p.unit_price,
        p.cost_price,
        p.gross_margin_pct,
        p.price_tier,
        round(o.net_amount - (p.cost_price * o.quantity), 2) as order_profit,

        -- Customer dimensions
        c.country,
        c.customer_segment,
        c.churn_risk

    from orders o
    left join products  p on o.product_id  = p.product_id
    left join {{ ref('mart_customer_360') }} c on o.customer_id = c.customer_id
),

-- Daily revenue summary
daily_revenue as (
    select
        cast(order_date as date)                             as revenue_date,
        order_month,
        order_week,
        category,
        sub_category,
        price_tier,
        country,
        customer_segment,

        count(*)                                             as total_orders,
        count(case when is_completed then 1 end)            as completed_orders,
        sum(case when is_completed then gross_amount end)   as gross_revenue,
        sum(case when is_completed then net_amount end)     as net_revenue,
        sum(case when is_completed then discount_amount end) as total_discounts,
        sum(case when is_completed then shipping_cost end)  as shipping_revenue,
        sum(case when is_completed then order_profit end)   as total_profit,
        sum(case when is_completed then quantity end)        as units_sold,
        avg(case when is_completed then net_amount end)     as avg_order_value,
        round(
            sum(case when is_completed then order_profit end)
            / nullif(sum(case when is_completed then net_amount end), 0) * 100
        , 2)                                                 as profit_margin_pct,

        current_timestamp()                                  as dbt_updated_at

    from order_enriched
    group by 1,2,3,4,5,6,7,8
)

select * from daily_revenue
