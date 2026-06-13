-- models/staging/stg_sessions.sql
-- Cleans web session data for funnel and attribution analysis

with source as (
    select * from {{ ref('raw_sessions') }}
),

renamed as (
    select
        session_id,
        customer_id,
        cast(session_date as date)                           as session_date,

        -- Channel standardization
        lower(trim(channel))                                 as channel,
        case
            when lower(trim(channel)) in ('organic_search','direct')
                then 'Organic'
            when lower(trim(channel)) in ('paid_search','social')
                then 'Paid'
            when lower(trim(channel)) = 'email'
                then 'Owned'
            else 'Referral'
        end                                                  as channel_group,

        -- Engagement metrics
        pages_visited,
        time_on_site,
        round(time_on_site / 60.0, 1)                       as time_on_site_mins,
        case
            when pages_visited = 1 and time_on_site < 10 then true
            else false
        end                                                  as is_bounce,

        -- Conversion
        cast(converted as boolean)                           as converted,

        current_timestamp()                                  as dbt_updated_at

    from source
    where session_id is not null
)

select * from renamed
