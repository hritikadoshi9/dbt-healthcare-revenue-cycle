-- Test: every claim with status='denied' should have at least one
-- corresponding record in fct_denials

select
    c.claim_key,
    c.claim_id,
    c.claim_status
from {{ ref('fct_claims') }} c
left join {{ ref('fct_denials') }} d on c.claim_id = d.claim_id
where c.is_denied = true
  and d.denial_id is null
