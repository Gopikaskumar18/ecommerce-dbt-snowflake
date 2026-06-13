-- analyses/cohort_retention.sql
-- Monthly cohort retention analysis
-- Run with: dbt compile --select cohort_retention

with orders as (
    select * from {{ ref('stg_orders') }}
    where status = 'completed'
),

-- First order per customer = cohort assignment
customer_cohorts as (
    select
        customer_id,
        date_trunc('month', min(order_date)) as cohort_month
    from orders
    group by 1
),

-- All orders tagged with cohort
order_with_cohort as (
    select
        o.customer_id,
        c.cohort_month,
        date_trunc('month', o.order_date)    as order_month,
        datediff('month', c.cohort_month,
                 date_trunc('month', o.order_date)) as months_since_cohort
    from orders o
    join customer_cohorts c on o.customer_id = c.customer_id
),

-- Count active customers per cohort per month
cohort_sizes as (
    select cohort_month, count(distinct customer_id) as cohort_size
    from customer_cohorts
    group by 1
),

retention_grid as (
    select
        o.cohort_month,
        o.months_since_cohort,
        count(distinct o.customer_id)         as active_customers
    from order_with_cohort o
    group by 1, 2
)

select
    r.cohort_month,
    r.months_since_cohort,
    r.active_customers,
    cs.cohort_size,
    round(r.active_customers * 100.0 / cs.cohort_size, 1) as retention_rate
from retention_grid r
join cohort_sizes cs on r.cohort_month = cs.cohort_month
order by 1, 2
