{{
    config(
        materialized='table',
        unique_key='aging_key'
    )
}}

{%- set aging_buckets = var('aging_buckets', [30, 60, 90, 120]) -%}

with claims as (
    select * from {{ ref('fct_claims') }}
    where is_paid = false
      and is_denied = false
),

final as (
    select
        -- Surrogate key
        {{ dbt_utils.generate_surrogate_key(['claim_id', 'claim_line_id']) }} as aging_key,

        -- Keys
        claim_id,
        claim_line_id,
        provider_key,
        payer_key,
        patient_key,
        procedure_key,

        -- Dates
        service_date,
        submission_date,

        -- Financials
        billed_amount,
        paid_amount,
        outstanding_balance,

        -- Days outstanding from submission
        {{ dbt.datediff("submission_date", "current_date", "day") }} as days_outstanding,

        -- Aging bucket assignment
        case
            {%- for i in range(aging_buckets | length) %}
            {%- if i == 0 %}
            when {{ dbt.datediff("submission_date", "current_date", "day") }} <= {{ aging_buckets[i] }}
                then '0-{{ aging_buckets[i] }} days'
            {%- else %}
            when {{ dbt.datediff("submission_date", "current_date", "day") }} <= {{ aging_buckets[i] }}
                then '{{ aging_buckets[i-1] + 1 }}-{{ aging_buckets[i] }} days'
            {%- endif %}
            {%- endfor %}
            else '{{ aging_buckets[-1] + 1 }}+ days'
        end as aging_bucket,

        -- Aging bucket sort order
        case
            {%- for i in range(aging_buckets | length) %}
            {%- if i == 0 %}
            when {{ dbt.datediff("submission_date", "current_date", "day") }} <= {{ aging_buckets[i] }}
                then {{ i + 1 }}
            {%- else %}
            when {{ dbt.datediff("submission_date", "current_date", "day") }} <= {{ aging_buckets[i] }}
                then {{ i + 1 }}
            {%- endif %}
            {%- endfor %}
            else {{ aging_buckets | length + 1 }}
        end as aging_bucket_sort,

        -- Risk flags
        case
            when {{ dbt.datediff("submission_date", "current_date", "day") }} > {{ aging_buckets[-1] }}
            then true
            else false
        end as is_at_risk,

        case
            when {{ dbt.datediff("submission_date", "current_date", "day") }} > {{ aging_buckets[-1] }}
                and outstanding_balance > 5000
            then 'critical'
            when {{ dbt.datediff("submission_date", "current_date", "day") }} > {{ aging_buckets[-2] }}
            then 'high'
            when {{ dbt.datediff("submission_date", "current_date", "day") }} > {{ aging_buckets[0] }}
            then 'medium'
            else 'low'
        end as collection_risk_level,

        current_timestamp as dbt_loaded_at

    from claims
    where outstanding_balance > 0
)

select * from final
