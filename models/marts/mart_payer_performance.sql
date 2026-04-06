{{
    config(
        materialized='table',
        unique_key='payer_performance_key'
    )
}}

with claims as (
    select * from {{ ref('fct_claims') }}
),

payments as (
    select * from {{ ref('fct_payments') }}
),

payers as (
    select * from {{ ref('dim_payers') }}
),

claim_metrics as (
    select
        c.payer_key,
        date_trunc('month', c.service_date)::date as service_month,

        -- Volume
        count(distinct c.claim_id)                  as total_claims,
        count(distinct c.claim_line_id)             as total_claim_lines,

        -- Financials
        sum(c.billed_amount)                        as total_billed,
        sum(c.paid_amount)                          as total_paid,
        sum(c.allowed_amount)                       as total_allowed,
        sum(c.adjustment_amount)                    as total_adjustments,
        sum(c.denied_amount)                        as total_denied,
        sum(c.patient_responsibility)               as total_patient_responsibility,
        sum(c.outstanding_balance)                  as total_outstanding,

        -- Rates
        case
            when sum(c.billed_amount) > 0
            then round(sum(c.paid_amount) / sum(c.billed_amount) * 100, 2)
            else 0
        end as collection_rate_pct,

        -- Denial metrics
        sum(case when c.is_denied then 1 else 0 end)       as denied_claims,
        sum(case when c.has_denial_history then 1 else 0 end) as claims_with_denials,

        case
            when count(distinct c.claim_id) > 0
            then round(
                sum(case when c.is_denied then 1 else 0 end)::numeric
                / count(distinct c.claim_id) * 100,
                2
            )
            else 0
        end as denial_rate_pct,

        -- Timing
        round(avg(c.days_to_first_payment), 1)      as avg_days_to_payment,
        round(avg(c.days_service_to_submission), 1)  as avg_days_to_submit,

        -- Status distribution
        sum(case when c.is_paid then 1 else 0 end)     as paid_claims,
        sum(case when c.is_pending then 1 else 0 end)  as pending_claims

    from claims c
    group by 1, 2
),

payment_methods as (
    select
        payer_key,
        date_trunc('month', payment_date)::date as payment_month,
        payment_method,
        count(*) as payment_count,
        sum(paid_amount) as method_total
    from payments
    group by 1, 2, 3
),

final as (
    select
        {{ dbt_utils.generate_surrogate_key([
            'cm.payer_key',
            'cm.service_month'
        ]) }} as payer_performance_key,

        cm.payer_key,
        cm.service_month,

        -- Payer attributes
        p.payer_name,
        p.plan_type,
        p.payer_category,
        p.contracted_rate_pct,
        p.reimbursement_tier,
        p.is_government_payer,

        -- Volume metrics
        cm.total_claims,
        cm.total_claim_lines,

        -- Financial metrics
        cm.total_billed,
        cm.total_paid,
        cm.total_allowed,
        cm.total_adjustments,
        cm.total_denied,
        cm.total_patient_responsibility,
        cm.total_outstanding,
        cm.collection_rate_pct,

        -- Contract performance: actual vs contracted
        case
            when p.contracted_rate_pct > 0
            then round(cm.collection_rate_pct - p.contracted_rate_pct, 2)
            else null
        end as contract_performance_variance_pct,

        -- Denial metrics
        cm.denied_claims,
        cm.claims_with_denials,
        cm.denial_rate_pct,

        -- Timing metrics
        cm.avg_days_to_payment,
        cm.avg_days_to_submit,

        -- Status distribution
        cm.paid_claims,
        cm.pending_claims,

        -- Payer score (composite metric)
        round(
            (cm.collection_rate_pct * 0.4)
            + ((100 - cm.denial_rate_pct) * 0.3)
            + (case when cm.avg_days_to_payment <= 30 then 100
                    when cm.avg_days_to_payment <= 60 then 75
                    when cm.avg_days_to_payment <= 90 then 50
                    else 25 end * 0.3),
            1
        ) as payer_performance_score,

        current_timestamp as dbt_loaded_at

    from claim_metrics cm
    left join payers p on cm.payer_key = p.payer_key
)

select * from final
