-- Test: denial_date should be on or after submission_date
-- A claim cannot be denied before it was submitted

select
    denial_key,
    denial_id,
    claim_id,
    submission_date,
    denial_date,
    {{ dbt.datediff("submission_date", "denial_date", "day") }} as days_diff
from {{ ref('fct_denials') }}
where denial_date < submission_date
