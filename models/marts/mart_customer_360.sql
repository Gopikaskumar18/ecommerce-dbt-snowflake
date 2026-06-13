-- models/marts/mart_customer_360.sql
-- Gold layer: one row per customer with full lifetime metrics
-- Powers: executive dashboards, retention analysis, segmentation
-- Scale: 5K customers, joins 50K orders + 100K sessions
-- Performance: cluster key on (customer_segment, churn_risk) prunes ~70% of
--              rows on the most common dashboard filter patterns

{{
    config(
        materialized='table',
        cluster_by=['customer_segment', 'churn_risk'],
        tags=['mart', 'customer', 'daily']
    )
}}

with customers as (
    select * from {{ ref('stg_customers') }}
),

orders as (
    select * from {{ ref('stg_orders') }}
    where status = 'completed'
),

sessions as (
    select * from {{ ref('stg_sessions') }}
),

-- Customer order aggregates
customer_orders as (
    select
        customer_id,
        count(*)                                             as total_orders,
        sum(gross_amount)                                    as total_gross_revenue,
        sum(net_amount)                                      as total_net_revenue,
        sum(discount_amount)                                 as total_discounts,
        avg(net_amount)                                      as avg_order_value,
        min(order_date)                                      as first_order_date,
        max(order_date)                                      as last_order_date,
        datediff('day', max(order_date), current_date())     as days_since_last_order,
        datediff('day', min(order_date), max(order_date))    as customer_lifespan_days,
        count(distinct date_trunc('month', order_date))      as active_months
    from orders
    group by 1
),

-- Customer session aggregates
customer_sessions as (
    select
        customer_id,
        count(*)                                             as total_sessions,
        sum(case when converted then 1 else 0 end)           as converting_sessions,
        avg(time_on_site)                                    as avg_time_on_site_secs,
        avg(pages_visited)                                   as avg_pages_per_session,
        round(
            sum(case when converted then 1 else 0 end) * 100.0
            / nullif(count(*), 0), 2
        )                                                    as session_conversion_rate
    from sessions
    group by 1
),

final as (
    select
        c.customer_id,
        c.full_name,
        c.email,
        c.country,
        c.signup_date,
        c.days_since_signup,
        c.customer_segment,

        -- Order metrics
        coalesce(o.total_orders, 0)                          as total_orders,
        coalesce(o.total_gross_revenue, 0)                   as total_gross_revenue,
        coalesce(o.total_net_revenue, 0)                     as total_net_revenue,
        coalesce(o.total_discounts, 0)                       as total_discounts,
        coalesce(o.avg_order_value, 0)                       as avg_order_value,
        o.first_order_date,
        o.last_order_date,
        coalesce(o.days_since_last_order, 9999)              as days_since_last_order,
        coalesce(o.customer_lifespan_days, 0)                as customer_lifespan_days,
        coalesce(o.active_months, 0)                         as active_months,

        -- Session metrics
        coalesce(s.total_sessions, 0)                        as total_sessions,
        coalesce(s.avg_time_on_site_secs, 0)                 as avg_time_on_site_secs,
        coalesce(s.avg_pages_per_session, 0)                 as avg_pages_per_session,
        coalesce(s.session_conversion_rate, 0)               as session_conversion_rate,

        -- Derived KPIs
        round(coalesce(o.total_net_revenue, 0) /
              nullif(c.days_since_signup, 0) * 365, 2)       as annualized_revenue,

        -- RFM scoring (Recency / Frequency / Monetary)
        case
            when coalesce(o.days_since_last_order,9999) <= 30  then 5
            when coalesce(o.days_since_last_order,9999) <= 60  then 4
            when coalesce(o.days_since_last_order,9999) <= 90  then 3
            when coalesce(o.days_since_last_order,9999) <= 180 then 2
            else 1
        end                                                  as recency_score,

        case
            when coalesce(o.total_orders,0) >= 20 then 5
            when coalesce(o.total_orders,0) >= 10 then 4
            when coalesce(o.total_orders,0) >= 5  then 3
            when coalesce(o.total_orders,0) >= 2  then 2
            else 1
        end                                                  as frequency_score,

        case
            when coalesce(o.total_net_revenue,0) >= 2000 then 5
            when coalesce(o.total_net_revenue,0) >= 1000 then 4
            when coalesce(o.total_net_revenue,0) >= 500  then 3
            when coalesce(o.total_net_revenue,0) >= 200  then 2
            else 1
        end                                                  as monetary_score,

        -- Churn risk
        case
            when coalesce(o.days_since_last_order,9999) > 180 then 'High Risk'
            when coalesce(o.days_since_last_order,9999) > 90  then 'Medium Risk'
            else 'Low Risk'
        end                                                  as churn_risk,

        current_timestamp()                                  as dbt_updated_at

    from customers c
    left join customer_orders  o on c.customer_id = o.customer_id
    left join customer_sessions s on c.customer_id = s.customer_id
)

select * from final
