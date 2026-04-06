with source as (
    select * from {{ source('healthcare', 'denials') }}
),

cleaned as (
    select
        -- Primary key
        cast(denial_id as {{ dbt.type_string() }})                  as denial_id,

        -- Foreign keys
        cast(claim_id as {{ dbt.type_string() }})                   as claim_id,

        -- Dates
        cast(denial_date as date)                                    as denial_date,
        cast(appeal_date as date)                                    as appeal_date,
        cast(appeal_resolution_date as date)                         as appeal_resolution_date,

        -- Denial codes
        upper(trim(denial_reason_code))                              as denial_reason_code,
        upper(trim(coalesce(remark_code, '')))                       as remark_code,

        -- Financials
        round(cast(denied_amount as {{ dbt.type_numeric() }}), 2)   as denied_amount,

        -- Appeal tracking
        lower(trim(coalesce(appeal_status, 'none')))                 as appeal_status,

        -- Derived fields
        case
            when appeal_status is not null
                and lower(trim(appeal_status)) != 'none'
            then true
            else false
        end                                                          as is_appealed,

        case
            when lower(trim(appeal_status)) = 'overturned'
            then true
            else false
        end                                                          as is_appeal_overturned,

        -- Metadata
        _loaded_at

    from source
    where denial_id is not null
)

select * from cleaned
