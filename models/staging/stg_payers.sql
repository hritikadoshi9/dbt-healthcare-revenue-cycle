with source as (
    select * from {{ source('healthcare', 'payers') }}
),

cleaned as (
    select
        cast(payer_id as {{ dbt.type_string() }})                       as payer_id,
        trim(payer_name)                                                 as payer_name,
        lower(trim(plan_type))                                           as plan_type,
        lower(trim(payer_category))                                      as payer_category,
        cast(contract_effective_date as date)                            as contract_effective_date,
        cast(contract_end_date as date)                                  as contract_end_date,
        round(cast(contracted_rate_pct as {{ dbt.type_numeric() }}), 2) as contracted_rate_pct,

        -- Derived: is contract currently active?
        case
            when contract_end_date is null
                or cast(contract_end_date as date) >= current_date
            then true
            else false
        end                                                              as is_contract_active,

        _loaded_at

    from source
    where payer_id is not null
)

select * from cleaned
