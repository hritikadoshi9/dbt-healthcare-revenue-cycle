{{
    config(
        materialized='table',
        unique_key='revenue_kpi_key'
    )
}}

with claims as (
    select * from {{ ref('fct_claims') }}
),

aging as (
    select * from {{ ref('fct_aging') }}
),

providers as (
    select * from {{ ref('dim_providers') }}
),

monthly_revenue as (
    select
        date_trunc('month', c.service_date)::date  as revenue_month,
        c.provider_key,

        -- Gross revenue
        sum(c.billed_amount)                        as gross_charges,

        -- Net revenue
        sum(c.paid_amount)                          as net_collections,
        sum(c.allowed_amount)                       as total_allowed,

        -- Adjustments
        sum(c.adjustment_amount)                    as contractual_adjustments,
        sum(c.denied_amount)                        as denial_write_offs,
        sum(c.patient_responsibility)               as patient_revenue,

        -- Volume
        count(distinct c.claim_id)                  as claim_volume,
        count(distinct c.claim_line_id)             as line_item_volume,

        -- Collection metrics
        case
            when sum(c.billed_amount) > 0
            then round(sum(c.paid_amount) / sum(c.billed_amount) * 100, 2)
            else 0
        end as gross_collection_rate,

        case
            when sum(c.allowed_amount) > 0
            then round(sum(c.paid_amount) / sum(c.allowed_amount) * 100, 2)
            else 0
        end as net_collection_rate,

        -- Average revenue per claim
        case
            when count(distinct c.claim_id) > 0
            then round(sum(c.paid_amount) / count(distinct c.claim_id), 2)
            else 0
        end as avg_revenue_per_claim,

        -- Denial rate
        case
            when count(distinct c.claim_id) > 0
            then round(
                sum(case when c.is_denied then 1 else 0 end)::numeric
                / count(distinct c.claim_id) * 100,
                2
            )
            else 0
        end as denial_rate,

        -- First pass resolution rate
        case
            when count(distinct c.claim_id) > 0
            then round(
                sum(case when c.is_paid and c.denial_count = 0 then 1 else 0 end)::numeric
                / count(distinct c.claim_id) * 100,
                2
            )
            else 0
        end as first_pass_resolution_rate,

        -- Days in AR
        round(avg(c.days_to_first_payment), 1)      as avg_days_in_ar,

        -- Clean claim rate (paid without any issues)
        case
            when count(distinct c.claim_id) > 0
            then round(
                sum(case
                    when c.is_paid
                        and c.denial_count = 0
                        and c.days_to_first_payment <= 30
                    then 1 else 0
                end)::numeric
                / count(distinct c.claim_id) * 100,
                2
            )
            else 0
        end as clean_claim_rate

    from claims c
    group by 1, 2
),

ar_summary as (
    select
        provider_key,
        sum(outstanding_balance)                                as total_ar_balance,
        sum(case when aging_bucket_sort = 1 then outstanding_balance else 0 end) as ar_0_30,
        sum(case when aging_bucket_sort = 2 then outstanding_balance else 0 end) as ar_31_60,
        sum(case when aging_bucket_sort = 3 then outstanding_balance else 0 end) as ar_61_90,
        sum(case when aging_bucket_sort = 4 then outstanding_balance else 0 end) as ar_91_120,
        sum(case when aging_bucket_sort >= 5 then outstanding_balance else 0 end) as ar_120_plus,
        count(case when is_at_risk then 1 end)                  as at_risk_claims,
        round(avg(days_outstanding), 1)                         as avg_days_outstanding
    from aging
    group by 1
),

final as (
    select
        {{ dbt_utils.generate_surrogate_key([
            'mr.provider_key',
            'mr.revenue_month'
        ]) }} as revenue_kpi_key,

        mr.revenue_month,
        mr.provider_key,

        -- Provider details
        p.provider_name,
        p.specialty,
        p.specialty_category,
        p.practice_name,

        -- Revenue metrics
        mr.gross_charges,
        mr.net_collections,
        mr.total_allowed,
        mr.contractual_adjustments,
        mr.denial_write_offs,
        mr.patient_revenue,

        -- Volume
        mr.claim_volume,
        mr.line_item_volume,

        -- KPI rates
        mr.gross_collection_rate,
        mr.net_collection_rate,
        mr.avg_revenue_per_claim,
        mr.denial_rate,
        mr.first_pass_resolution_rate,
        mr.clean_claim_rate,
        mr.avg_days_in_ar,

        -- AR aging snapshot
        coalesce(ar.total_ar_balance, 0)    as total_ar_balance,
        coalesce(ar.ar_0_30, 0)             as ar_0_30,
        coalesce(ar.ar_31_60, 0)            as ar_31_60,
        coalesce(ar.ar_61_90, 0)            as ar_61_90,
        coalesce(ar.ar_91_120, 0)           as ar_91_120,
        coalesce(ar.ar_120_plus, 0)         as ar_120_plus,
        coalesce(ar.at_risk_claims, 0)      as at_risk_claims,
        coalesce(ar.avg_days_outstanding, 0) as avg_days_outstanding,

        -- AR concentration (% of AR in 90+ days)
        case
            when coalesce(ar.total_ar_balance, 0) > 0
            then round(
                (coalesce(ar.ar_91_120, 0) + coalesce(ar.ar_120_plus, 0))
                / ar.total_ar_balance * 100,
                2
            )
            else 0
        end as ar_over_90_pct,

        -- Revenue health score (composite)
        round(
            (mr.net_collection_rate * 0.25)
            + (mr.first_pass_resolution_rate * 0.25)
            + ((100 - mr.denial_rate) * 0.20)
            + (mr.clean_claim_rate * 0.15)
            + (case
                when mr.avg_days_in_ar <= 25 then 100
                when mr.avg_days_in_ar <= 40 then 80
                when mr.avg_days_in_ar <= 60 then 60
                when mr.avg_days_in_ar <= 90 then 40
                else 20
              end * 0.15),
            1
        ) as revenue_health_score,

        current_timestamp as dbt_loaded_at

    from monthly_revenue mr
    left join ar_summary ar on mr.provider_key = ar.provider_key
    left join providers p on mr.provider_key = p.provider_key
)

select * from final
