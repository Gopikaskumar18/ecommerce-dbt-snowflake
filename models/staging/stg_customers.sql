-- models/staging/stg_customers.sql
-- Cleans and standardizes raw customer records

with source as (
    select * from {{ ref('raw_customers') }}
),

renamed as (
    select
        customer_id,

        -- Name cleaning
        initcap(trim(first_name))                            as first_name,
        initcap(trim(last_name))                             as last_name,
        initcap(trim(first_name)) || ' ' ||
        initcap(trim(last_name))                             as full_name,
        lower(trim(email))                                   as email,

        -- Geography
        initcap(trim(country))                               as country,

        -- Dates
        cast(signup_date as date)                            as signup_date,
        datediff('day', cast(signup_date as date),
                 current_date())                             as days_since_signup,
        datediff('month', cast(signup_date as date),
                 current_date())                             as months_since_signup,

        -- Segment
        initcap(trim(segment))                               as customer_segment,

        -- Metadata
        current_timestamp()                                  as dbt_updated_at

    from source
    where customer_id is not null
      and email is not null
)

select * from renamed
