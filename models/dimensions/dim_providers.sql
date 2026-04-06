{{
    config(
        materialized='table',
        unique_key='provider_key'
    )
}}

with providers as (
    select * from {{ ref('stg_providers') }}
),

final as (
    select
        {{ dbt_utils.generate_surrogate_key(['provider_id']) }}  as provider_key,
        provider_id,
        npi,
        provider_name,
        provider_type,
        specialty,
        practice_name,
        practice_state,
        is_active,

        -- Provider classification
        case
            when specialty in ('Family Medicine', 'Internal Medicine', 'Pediatrics', 'General Practice')
                then 'Primary Care'
            when specialty in ('Cardiology', 'Orthopedics', 'Neurology', 'Oncology', 'Gastroenterology',
                               'Pulmonology', 'Endocrinology', 'Rheumatology', 'Nephrology', 'Dermatology')
                then 'Specialty'
            when specialty in ('General Surgery', 'Orthopedic Surgery', 'Cardiovascular Surgery', 'Neurosurgery')
                then 'Surgical'
            when specialty in ('Emergency Medicine', 'Urgent Care')
                then 'Emergency'
            when specialty in ('Radiology', 'Pathology', 'Anesthesiology')
                then 'Ancillary'
            else 'Other'
        end as specialty_category,

        current_timestamp as dbt_loaded_at

    from providers
)

select * from final
