{{
    config(
        materialized='table',
        unique_key='payer_key'
    )
}}

with payers as (
    select * from {{ ref('stg_payers') }}
),

final as (
    select
        {{ dbt_utils.generate_surrogate_key(['payer_id']) }}  as payer_key,
        payer_id,
        payer_name,
        plan_type,
        payer_category,
        contract_effective_date,
        contract_end_date,
        contracted_rate_pct,
        is_contract_active,

        -- Payer tier based on reimbursement rate
        case
            when contracted_rate_pct >= 80 then 'tier_1_high'
            when contracted_rate_pct >= 60 then 'tier_2_medium'
            when contracted_rate_pct >= 40 then 'tier_3_low'
            else 'tier_4_minimal'
        end as reimbursement_tier,

        -- Government vs commercial flag
        case
            when payer_category = 'government' then true
            else false
        end as is_government_payer,

        current_timestamp as dbt_loaded_at

    from payers
)

select * from final
