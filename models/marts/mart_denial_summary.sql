{{
    config(
        materialized='table',
        unique_key='denial_summary_key'
    )
}}

with denials as (
    select * from {{ ref('fct_denials') }}
),

summary as (
    select
        {{ dbt_utils.generate_surrogate_key([
            'payer_key',
            'denial_category',
            "date_trunc('month', denial_date)"
        ]) }} as denial_summary_key,

        payer_key,
        denial_category,
        date_trunc('month', denial_date)::date  as denial_month,

        -- Volume metrics
        count(*)                                 as total_denials,
        count(distinct claim_id)                 as unique_claims_denied,

        -- Financial metrics
        sum(denied_amount)                       as total_denied_amount,
        round(avg(denied_amount), 2)             as avg_denied_amount,
        max(denied_amount)                       as max_denied_amount,
        sum(billed_amount)                       as total_billed_amount,

        -- Denial rate
        case
            when sum(billed_amount) > 0
            then round(sum(denied_amount) / sum(billed_amount) * 100, 2)
            else 0
        end as denial_rate_pct,

        -- Appeal metrics
        sum(case when is_appealed then 1 else 0 end)               as appeals_submitted,
        sum(case when is_appeal_overturned then 1 else 0 end)      as appeals_overturned,

        case
            when sum(case when is_appealed then 1 else 0 end) > 0
            then round(
                sum(case when is_appeal_overturned then 1 else 0 end)::numeric
                / sum(case when is_appealed then 1 else 0 end) * 100,
                2
            )
            else 0
        end as appeal_overturn_rate_pct,

        -- Appeal ROI: amount recovered through successful appeals
        sum(
            case when is_appeal_overturned then denied_amount else 0 end
        ) as recovered_through_appeals,

        -- Timing metrics
        round(avg(days_submission_to_denial), 1)    as avg_days_to_denial,
        round(avg(days_denial_to_appeal), 1)        as avg_days_to_appeal,
        round(avg(days_appeal_to_resolution), 1)    as avg_days_to_resolution,

        -- Impact distribution
        sum(case when denial_impact_tier = 'critical' then 1 else 0 end) as critical_denials,
        sum(case when denial_impact_tier = 'high' then 1 else 0 end)     as high_impact_denials,
        sum(case when denial_impact_tier = 'medium' then 1 else 0 end)   as medium_impact_denials,
        sum(case when denial_impact_tier = 'low' then 1 else 0 end)      as low_impact_denials,

        -- Top denial reason codes (for reporting)
        string_agg(distinct denial_reason_code, ', ' order by denial_reason_code) as denial_reason_codes_list,

        current_timestamp as dbt_loaded_at

    from denials
    group by 1, 2, 3, 4
)

select * from summary
