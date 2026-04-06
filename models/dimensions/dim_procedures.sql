{{
    config(
        materialized='table',
        unique_key='procedure_key'
    )
}}

with procedures as (
    select * from {{ ref('stg_procedures') }}
),

final as (
    select
        {{ dbt_utils.generate_surrogate_key(['procedure_code']) }}  as procedure_key,
        procedure_code,
        procedure_description,
        procedure_category,
        code_type,
        standard_charge,
        rvu_work,
        rvu_practice,
        rvu_malpractice,
        rvu_total,

        -- Cost complexity tier based on standard charge
        case
            when standard_charge >= 5000 then 'high_cost'
            when standard_charge >= 1000 then 'medium_cost'
            when standard_charge >= 250  then 'low_cost'
            else 'minimal_cost'
        end as cost_tier,

        -- RVU complexity tier
        case
            when rvu_total >= 10 then 'high_complexity'
            when rvu_total >= 5  then 'medium_complexity'
            when rvu_total >= 1  then 'low_complexity'
            else 'minimal_complexity'
        end as rvu_complexity_tier,

        current_timestamp as dbt_loaded_at

    from procedures
)

select * from final
