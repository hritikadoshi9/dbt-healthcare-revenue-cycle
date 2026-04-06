with source as (
    select * from {{ source('healthcare', 'patients') }}
),

cleaned as (
    select
        cast(patient_id as {{ dbt.type_string() }})             as patient_id,
        cast(date_of_birth as date)                              as date_of_birth,
        lower(trim(gender))                                      as gender,
        cast(zip_code as {{ dbt.type_string() }})               as zip_code,
        cast(primary_payer_id as {{ dbt.type_string() }})       as primary_payer_id,
        cast(secondary_payer_id as {{ dbt.type_string() }})     as secondary_payer_id,
        cast(coverage_start_date as date)                        as coverage_start_date,
        cast(coverage_end_date as date)                          as coverage_end_date,

        -- Derived: age bucket for analytics (no PHI)
        case
            when {{ dbt.datediff("date_of_birth", "current_date", "year") }} < 18 then 'pediatric'
            when {{ dbt.datediff("date_of_birth", "current_date", "year") }} < 40 then '18-39'
            when {{ dbt.datediff("date_of_birth", "current_date", "year") }} < 65 then '40-64'
            else '65+'
        end                                                      as age_group,

        -- Derived: has active coverage?
        case
            when coverage_end_date is null
                or cast(coverage_end_date as date) >= current_date
            then true
            else false
        end                                                      as has_active_coverage,

        _loaded_at

    from source
    where patient_id is not null
)

select * from cleaned
