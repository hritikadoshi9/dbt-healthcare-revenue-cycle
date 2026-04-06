with source as (
    select * from {{ source('healthcare', 'procedures') }}
),

cleaned as (
    select
        upper(trim(procedure_code))                                      as procedure_code,
        trim(procedure_description)                                      as procedure_description,
        lower(trim(procedure_category))                                  as procedure_category,
        lower(trim(code_type))                                           as code_type,
        round(cast(standard_charge as {{ dbt.type_numeric() }}), 2)     as standard_charge,
        round(cast(coalesce(rvu_work, 0) as {{ dbt.type_numeric() }}), 2)        as rvu_work,
        round(cast(coalesce(rvu_practice, 0) as {{ dbt.type_numeric() }}), 2)    as rvu_practice,
        round(cast(coalesce(rvu_malpractice, 0) as {{ dbt.type_numeric() }}), 2) as rvu_malpractice,

        -- Derived: total RVU
        round(
            cast(coalesce(rvu_work, 0) as {{ dbt.type_numeric() }})
            + cast(coalesce(rvu_practice, 0) as {{ dbt.type_numeric() }})
            + cast(coalesce(rvu_malpractice, 0) as {{ dbt.type_numeric() }}),
            2
        )                                                                as rvu_total,

        _loaded_at

    from source
    where procedure_code is not null
)

select * from cleaned
