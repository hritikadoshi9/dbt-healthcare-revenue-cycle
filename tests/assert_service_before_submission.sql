-- Test: service_date should always be on or before submission_date
-- A claim cannot be submitted before the service was rendered

select
    claim_key,
    claim_id,
    service_date,
    submission_date,
    {{ dbt.datediff("service_date", "submission_date", "day") }} as days_diff
from {{ ref('fct_claims') }}
where service_date > submission_date
