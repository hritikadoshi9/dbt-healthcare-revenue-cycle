{{
    config(
        materialized='incremental',
        unique_key='payment_key',
        incremental_strategy='merge',
        on_schema_change='sync_all_columns'
    )
}}

with payments as (
    select * from {{ ref('stg_payments') }}
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
        submission_date
    from {{ ref('stg_claims') }}
),

dim_payers as (
    select payer_id, payer_key, contracted_rate_pct from {{ ref('dim_payers') }}
),

dim_providers as (
    select provider_id, provider_key from {{ ref('dim_providers') }}
),

final as (
    select
        -- Surrogate key
        {{ dbt_utils.generate_surrogate_key(['p.payment_id']) }} as payment_key,

        -- Natural keys
        p.payment_id,
        p.claim_id,

        -- Dimension keys
        dp.payer_key,
        dpr.provider_key,

        -- Dates
        c.service_date,
        c.submission_date,
        p.payment_date,

        -- Payment details
        p.payment_method,
        p.check_eft_number,

        -- Financial amounts
        c.billed_amount,
        p.allowed_amount,
        p.paid_amount,
        p.adjustment_amount,
        p.patient_responsibility,
        p.total_expected_collection,

        -- Reimbursement analysis
        case
            when c.billed_amount > 0
            then round(p.paid_amount / c.billed_amount * 100, 2)
            else 0
        end as reimbursement_rate_pct,

        case
            when p.allowed_amount > 0
            then round(p.paid_amount / p.allowed_amount * 100, 2)
            else 0
        end as paid_to_allowed_pct,

        -- Variance from contracted rate
        case
            when c.billed_amount > 0 and dp.contracted_rate_pct > 0
            then round(
                (p.paid_amount / c.billed_amount * 100) - dp.contracted_rate_pct,
                2
            )
            else null
        end as contract_variance_pct,

        -- Payment speed
        {{ dbt.datediff("c.submission_date", "p.payment_date", "day") }}
            as days_to_payment,

        -- Payment classification
        case
            when p.paid_amount >= c.billed_amount then 'full_payment'
            when p.paid_amount > 0                then 'partial_payment'
            else 'zero_payment'
        end as payment_classification,

        -- Metadata
        p._loaded_at,
        current_timestamp as dbt_loaded_at

    from payments p
    left join claims c on p.claim_id = c.claim_id
    left join dim_payers dp on p.payer_id = dp.payer_id
    left join dim_providers dpr on c.provider_id = dpr.provider_id
)

select * from final
