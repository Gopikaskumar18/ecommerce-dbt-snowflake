-- macros/generate_date_spine.sql
-- Reusable macro to generate a date range table
-- Usage: {{ generate_date_spine('2022-01-01', '2025-12-31') }}

{% macro generate_date_spine(start_date, end_date) %}

with date_spine as (
    {{ dbt_utils.date_spine(
        datepart="day",
        start_date="cast('" ~ start_date ~ "' as date)",
        end_date="cast('" ~ end_date ~ "' as date)"
    ) }}
),

final as (
    select
        cast(date_day as date)                              as date_day,
        year(date_day)                                      as year,
        month(date_day)                                     as month,
        day(date_day)                                       as day,
        quarter(date_day)                                   as quarter,
        dayofweek(date_day)                                 as day_of_week,
        dayname(date_day)                                   as day_name,
        monthname(date_day)                                 as month_name,
        date_trunc('week',  date_day)                       as week_start_date,
        date_trunc('month', date_day)                       as month_start_date,
        date_trunc('quarter', date_day)                     as quarter_start_date,
        case when dayofweek(date_day) in (0,6) then true
             else false end                                 as is_weekend
    from date_spine
)

select * from final

{% endmacro %}


-- macros/safe_divide.sql
{% macro safe_divide(numerator, denominator) %}
    case
        when {{ denominator }} = 0 or {{ denominator }} is null then null
        else {{ numerator }} / {{ denominator }}
    end
{% endmacro %}


-- macros/cents_to_dollars.sql
{% macro cents_to_dollars(column_name) %}
    round({{ column_name }} / 100.0, 2)
{% endmacro %}
