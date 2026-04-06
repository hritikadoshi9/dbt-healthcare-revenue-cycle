-- Test: fct_aging should not contain any claims that are already fully paid or denied
-- It should only track open receivables

select
    a.aging_key,
    a.claim_id,
    c.claim_status,
    c.is_paid,
    c.is_denied
from {{ ref('fct_aging') }} a
inner join {{ ref('fct_claims') }} c on a.claim_id = c.claim_id
where c.is_paid = true
   or c.is_denied = true
