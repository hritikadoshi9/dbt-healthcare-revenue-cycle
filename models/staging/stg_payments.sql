with source as (
    select * from {{ source('healthcare', 'payments') }}
),

cleaned as (
    select
        -- Primary key
        cast(payment_id as {{ dbt.type_string() }})                     as payment_id,

        -- Foreign keys
        cast(claim_id as {{ dbt.type_string() }})                       as claim_id,
        cast(payer_id as {{ dbt.type_string() }})                       as payer_id,

        -- Dates
        cast(payment_date as date)                                       as payment_date,

        -- Financials
        round(cast(paid_amount as {{ dbt.type_numeric() }}), 2)         as paid_amount,
        round(cast(allowed_amount as {{ dbt.type_numeric() }}), 2)      as allowed_amount,
        round(cast(adjustment_amount as {{ dbt.type_numeric() }}), 2)   as adjustment_amount,
        round(cast(patient_responsibility as {{ dbt.type_numeric() }}), 2) as patient_responsibility,

        -- Payment details
        lower(trim(payment_method))                                      as payment_method,
        cast(check_eft_number as {{ dbt.type_string() }})               as check_eft_number,

        -- Derived: net collection
        round(
            cast(paid_amount as {{ dbt.type_numeric() }})
            + cast(patient_responsibility as {{ dbt.type_numeric() }}),
            2
        )                                                                as total_expected_collection,

        -- Metadata
        _loaded_at

    from source
    where payment_id is not null
)

select * from cleaned
