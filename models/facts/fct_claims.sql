{{
    config(
        materialized='incremental',
        unique_key='claim_key',
        incremental_strategy='merge',
        on_schema_change='sync_all_columns'
    )
}}

with claims as (
    select * from {{ ref('stg_claims') }}
    {% if is_incremental() %}
    where _loaded_at > (select max(_loaded_at) from {{ this }})
    {% endif %}
),

payments as (
    select
        claim_id,
        sum(paid_amount)                as total_paid_amount,
        sum(allowed_amount)             as total_allowed_amount,
        sum(adjustment_amount)          as total_adjustment_amount,
        sum(patient_responsibility)     as total_patient_responsibility,
        min(payment_date)               as first_payment_date,
        max(payment_date)               as last_payment_date,
        count(*)                        as payment_count
    from {{ ref('stg_payments') }}
    group by 1
),

denials as (
    select
        claim_id,
        count(*)                                                    as denial_count,
        sum(denied_amount)                                          as total_denied_amount,
        max(case when is_appealed then 1 else 0 end)::boolean      as has_appeal,
        max(case when is_appeal_overturned then 1 else 0 end)::boolean as has_successful_appeal,
        min(denial_date)                                            as first_denial_date
    from {{ ref('stg_denials') }}
    group by 1
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
        {{ dbt_utils.generate_surrogate_key(['c.claim_id', 'c.claim_line_id']) }} as claim_key,

        -- Natural keys
        c.claim_id,
        c.claim_line_id,

        -- Dimension keys
        dp.provider_key,
        dpy.payer_key,
        dpt.patient_key,
        dpr.procedure_key,

        -- Dates
        c.service_date,
        c.submission_date,
        pay.first_payment_date,
        pay.last_payment_date,
        den.first_denial_date,

        -- Claim details
        c.procedure_code,
        c.diagnosis_code_primary,
        c.diagnosis_code_secondary,
        c.claim_status,
        c.place_of_service_code,

        -- Billed amounts
        c.billed_amount,

        -- Payment amounts
        coalesce(pay.total_paid_amount, 0)              as paid_amount,
        coalesce(pay.total_allowed_amount, 0)           as allowed_amount,
        coalesce(pay.total_adjustment_amount, 0)        as adjustment_amount,
        coalesce(pay.total_patient_responsibility, 0)   as patient_responsibility,
        coalesce(pay.payment_count, 0)                  as payment_count,

        -- Denial amounts
        coalesce(den.total_denied_amount, 0)            as denied_amount,
        coalesce(den.denial_count, 0)                   as denial_count,
        coalesce(den.has_appeal, false)                 as has_appeal,
        coalesce(den.has_successful_appeal, false)      as has_successful_appeal,

        -- Derived financial metrics
        c.billed_amount - coalesce(pay.total_paid_amount, 0)
            as outstanding_balance,

        case
            when c.billed_amount > 0
            then round(coalesce(pay.total_paid_amount, 0) / c.billed_amount * 100, 2)
            else 0
        end                                             as collection_rate_pct,

        case
            when c.billed_amount > 0
            then round(coalesce(pay.total_allowed_amount, 0) / c.billed_amount * 100, 2)
            else 0
        end                                             as allowed_rate_pct,

        -- Claim lifecycle timing (in days)
        {{ dbt.datediff("c.submission_date", "coalesce(pay.first_payment_date, current_date)", "day") }}
            as days_to_first_payment,

        {{ dbt.datediff("c.service_date", "c.submission_date", "day") }}
            as days_service_to_submission,

        -- Status flags
        case when c.claim_status = 'denied' then true else false end        as is_denied,
        case when c.claim_status = 'paid' then true else false end          as is_paid,
        case when c.claim_status = 'submitted' then true else false end     as is_pending,
        case when den.denial_count > 0 then true else false end             as has_denial_history,

        -- Metadata
        c._loaded_at,
        current_timestamp as dbt_loaded_at

    from claims c
    left join payments pay on c.claim_id = pay.claim_id
    left join denials den on c.claim_id = den.claim_id
    left join dim_providers dp on c.provider_id = dp.provider_id
    left join dim_payers dpy on c.payer_id = dpy.payer_id
    left join dim_patients dpt on c.patient_id = dpt.patient_id
    left join dim_procedures dpr on c.procedure_code = dpr.procedure_code
)

select * from final
