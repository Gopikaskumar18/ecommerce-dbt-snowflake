-- models/marts/mart_channel_attribution.sql
-- Gold layer: marketing channel performance
-- Powers: CAC analysis, channel ROI, campaign attribution
-- Scale: summarizes 100K sessions + 5K customer LTV records → 6-row summary
-- Design: first-touch attribution baseline; designed to extend to multi-touch
--         by swapping the first_touch CTE for a path-level session sequence

{{
    config(
        materialized='table',
        tags=['mart', 'marketing', 'daily']
    )
}}

with sessions as (
    select * from {{ ref('stg_sessions') }}
),

customers as (
    select * from {{ ref('mart_customer_360') }}
),

channel_daily as (
    select
        session_date,
        channel,
        channel_group,
        count(*)                                             as total_sessions,
        count(distinct customer_id)                          as unique_visitors,
        sum(case when converted  then 1 else 0 end)         as conversions,
        sum(case when is_bounce  then 1 else 0 end)         as bounces,
        avg(time_on_site_mins)                               as avg_time_on_site_mins,
        avg(pages_visited)                                   as avg_pages_per_session,
        round(
            sum(case when converted then 1.0 else 0 end)
            / nullif(count(*), 0) * 100, 2
        )                                                    as conversion_rate_pct,
        round(
            sum(case when is_bounce then 1.0 else 0 end)
            / nullif(count(*), 0) * 100, 2
        )                                                    as bounce_rate_pct

    from sessions
    group by 1, 2, 3
),

-- First-touch attribution: credit the first channel a customer came from
first_touch as (
    select
        customer_id,
        channel                                              as first_touch_channel,
        channel_group                                        as first_touch_channel_group,
        min(session_date)                                    as first_session_date
    from sessions
    group by 1, 2, 3
),

customer_attribution as (
    select
        ft.customer_id,
        ft.first_touch_channel,
        ft.first_touch_channel_group,
        c.total_orders,
        c.total_net_revenue,
        c.avg_order_value,
        c.customer_segment,
        c.country
    from first_touch ft
    left join customers c on ft.customer_id = c.customer_id
),

channel_ltv_summary as (
    select
        first_touch_channel,
        first_touch_channel_group,
        count(distinct customer_id)                          as acquired_customers,
        avg(total_net_revenue)                               as avg_customer_ltv,
        avg(total_orders)                                    as avg_orders_per_customer,
        avg(avg_order_value)                                 as avg_order_value,
        sum(total_net_revenue)                               as total_attributed_revenue,
        current_timestamp()                                  as dbt_updated_at
    from customer_attribution
    group by 1, 2
)

select * from channel_ltv_summary
