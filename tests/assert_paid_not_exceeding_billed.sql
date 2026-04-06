-- Test: paid_amount should not exceed billed_amount by more than 5%
-- A small tolerance is allowed for payer adjustments and corrections

select
    claim_key,
    claim_id,
    billed_amount,
    paid_amount,
    round((paid_amount - billed_amount) / nullif(billed_amount, 0) * 100, 2) as overpayment_pct
from {{ ref('fct_claims') }}
where paid_amount > billed_amount * 1.05
  and billed_amount > 0
