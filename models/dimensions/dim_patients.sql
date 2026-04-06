{{
    config(
        materialized='table',
        unique_key='patient_key'
    )
}}

with patients as (
    select * from {{ ref('stg_patients') }}
),

final as (
    select
        {{ dbt_utils.generate_surrogate_key(['patient_id']) }}  as patient_key,
        patient_id,
        date_of_birth,
        gender,
        zip_code,
        primary_payer_id,
        secondary_payer_id,
        coverage_start_date,
        coverage_end_date,
        age_group,
        has_active_coverage,

        -- Derived: has secondary insurance
        case
            when secondary_payer_id is not null then true
            else false
        end as has_secondary_insurance,

        -- Derived: coverage duration in months
        {{ dbt.datediff("coverage_start_date", "coalesce(coverage_end_date, current_date)", "month") }}
            as coverage_duration_months,

        current_timestamp as dbt_loaded_at

    from patients
)

select * from final
