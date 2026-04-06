with source as (
    select * from {{ source('healthcare', 'providers') }}
),

cleaned as (
    select
        cast(provider_id as {{ dbt.type_string() }})       as provider_id,
        cast(npi as {{ dbt.type_string() }})                as npi,
        trim(provider_name)                                  as provider_name,
        lower(trim(provider_type))                           as provider_type,
        trim(specialty)                                      as specialty,
        cast(tax_id as {{ dbt.type_string() }})             as tax_id,
        trim(practice_name)                                  as practice_name,
        upper(trim(practice_state))                          as practice_state,
        cast(is_active as boolean)                           as is_active,
        _loaded_at

    from source
    where provider_id is not null
)

select * from cleaned
