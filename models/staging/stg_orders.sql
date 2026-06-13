-- models/staging/stg_orders.sql
-- Cleans and standardizes raw orders from source

with source as (
    select * from {{ ref('raw_orders') }}
),

renamed as (
    select
        order_id,
        customer_id,
        product_id,

        -- Cast and clean dates
        cast(order_date as timestamp_ntz)                    as order_date,
        date_trunc('month', cast(order_date as date))        as order_month,
        date_trunc('week',  cast(order_date as date))        as order_week,
        dayofweek(cast(order_date as date))                  as order_day_of_week,

        -- Standardize status
        lower(trim(status))                                  as status,
        case
            when lower(trim(status)) = 'completed'  then true
            else false
        end                                                  as is_completed,

        -- Financial fields
        round(amount, 2)                                     as gross_amount,
        round(discount, 2)                                   as discount_amount,
        round(shipping_cost, 2)                              as shipping_cost,
        round(amount - discount, 2)                          as net_amount,
        round(amount - discount + shipping_cost, 2)          as total_amount,

        quantity,

        -- Metadata
        current_timestamp()                                  as dbt_updated_at

    from source
    where order_id is not null
      and customer_id is not null
      and amount > 0
)

select * from renamed
