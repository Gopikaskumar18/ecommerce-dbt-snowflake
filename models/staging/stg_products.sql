-- models/staging/stg_products.sql
-- Cleans and enriches raw product records

with source as (
    select * from {{ ref('raw_products') }}
),

renamed as (
    select
        product_id,
        trim(product_name)                                   as product_name,
        initcap(trim(category))                              as category,
        initcap(trim(sub_category))                          as sub_category,

        -- Pricing
        round(unit_price, 2)                                 as unit_price,
        round(cost_price, 2)                                 as cost_price,
        round(unit_price - cost_price, 2)                    as gross_margin_amount,
        round((unit_price - cost_price) / nullif(unit_price, 0) * 100, 2)
                                                             as gross_margin_pct,

        -- Price tiers
        case
            when unit_price < 25  then 'Budget'
            when unit_price < 75  then 'Mid-Range'
            when unit_price < 150 then 'Premium'
            else 'Luxury'
        end                                                  as price_tier,

        current_timestamp()                                  as dbt_updated_at

    from source
    where product_id is not null
      and unit_price > 0
)

select * from renamed
