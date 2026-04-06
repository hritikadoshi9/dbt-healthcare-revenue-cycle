with source as (
    select * from {{ source('healthcare', 'claims') }}
),

cleaned as (
    select
        -- Primary keys
        cast(claim_id as {{ dbt.type_string() }})                   as claim_id,
        cast(claim_line_id as {{ dbt.type_string() }})              as claim_line_id,

        -- Foreign keys
        cast(patient_id as {{ dbt.type_string() }})                 as patient_id,
        cast(provider_id as {{ dbt.type_string() }})                as provider_id,
        cast(payer_id as {{ dbt.type_string() }})                   as payer_id,

        -- Procedure and diagnosis codes
        upper(trim(procedure_code))                                  as procedure_code,
        upper(trim(diagnosis_code_primary))                          as diagnosis_code_primary,
        upper(trim(coalesce(diagnosis_code_secondary, '')))          as diagnosis_code_secondary,

        -- Dates
        cast(service_date as date)                                   as service_date,
        cast(submission_date as date)                                as submission_date,

        -- Financials
        round(cast(billed_amount as {{ dbt.type_numeric() }}), 2)   as billed_amount,

        -- Status
        lower(trim(claim_status))                                    as claim_status,

        -- Place of service
        cast(place_of_service_code as {{ dbt.type_string() }})      as place_of_service_code,

        -- Metadata
        _loaded_at

    from source
    where claim_id is not null
)

select * from cleaned
