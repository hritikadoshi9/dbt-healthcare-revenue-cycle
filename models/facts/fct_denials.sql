{{
    config(
        materialized='incremental',
        unique_key='denial_key',
        incremental_strategy='merge',
        on_schema_change='sync_all_columns'
    )
}}

with denials as (
    select * from {{ ref('stg_denials') }}
    {% if is_incremental() %}
    where _loaded_at > (select max(_loaded_at) from {{ this }})
    {% endif %}
),

claims as (
    select
        claim_id,
        patient_id,
        provider_id,
        payer_id,
        procedure_code,
        billed_amount,
        service_date,
        submission_date,
        place_of_service_code
    from {{ ref('stg_claims') }}
),

denial_codes as (
    select * from {{ ref('seed_denial_reason_codes') }}
),

-- Dimension keys
dim_providers as (
    select provider_id, provider_key from {{ ref('dim_providers') }}
),

dim_payers as (
    select payer_id, payer_key from {{ ref('dim_payers') }}
),

dim_patients as (
    select patient_id, patient_key from {{ ref('dim_patients') }}
),

dim_procedures as (
    select procedure_code, procedure_key from {{ ref('dim_procedures') }}
),

final as (
    select
        -- Surrogate key
        {{ dbt_utils.generate_surrogate_key(['d.denial_id']) }} as denial_key,

        -- Natural keys
        d.denial_id,
        d.claim_id,

        -- Dimension keys
        dp.provider_key,
        dpy.payer_key,
        dpt.patient_key,
        dpr.procedure_key,

        -- Dates
        c.service_date,
        c.submission_date,
        d.denial_date,
        d.appeal_date,
        d.appeal_resolution_date,

        -- Denial details
        d.denial_reason_code,
        d.remark_code,
        coalesce(dc.denial_description, 'Unknown')     as denial_description,
        coalesce(dc.denial_category, 'Uncategorized')  as denial_category,

        -- Financials
        c.billed_amount,
        d.denied_amount,

        -- Appeal tracking
        d.appeal_status,
        d.is_appealed,
        d.is_appeal_overturned,

        -- Timing metrics (in days)
        {{ dbt.datediff("c.submission_date", "d.denial_date", "day") }}
            as days_submission_to_denial,

        case
            when d.appeal_date is not null
            then {{ dbt.datediff("d.denial_date", "d.appeal_date", "day") }}
            else null
        end as days_denial_to_appeal,

        case
            when d.appeal_resolution_date is not null
            then {{ dbt.datediff("d.appeal_date", "d.appeal_resolution_date", "day") }}
            else null
        end as days_appeal_to_resolution,

        -- Denial impact classification
        case
            when d.denied_amount >= 10000 then 'critical'
            when d.denied_amount >= 5000  then 'high'
            when d.denied_amount >= 1000  then 'medium'
            else 'low'
        end as denial_impact_tier,

        -- Metadata
        d._loaded_at,
        current_timestamp as dbt_loaded_at

    from denials d
    left join claims c on d.claim_id = c.claim_id
    left join denial_codes dc on d.denial_reason_code = dc.denial_code
    left join dim_providers dp on c.provider_id = dp.provider_id
    left join dim_payers dpy on c.payer_id = dpy.payer_id
    left join dim_patients dpt on c.patient_id = dpt.patient_id
    left join dim_procedures dpr on c.procedure_code = dpr.procedure_code
)

select * from final
