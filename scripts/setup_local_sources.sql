-- ──────────────────────────────────────────────────────────────
-- Run this script AFTER `dbt seed` to create source views
-- that map seed tables to the expected source contract.
--
-- Usage:
--   dbt seed
--   psql -U dbt -d dbt -f scripts/setup_local_sources.sql
--   dbt build --full-refresh
-- ──────────────────────────────────────────────────────────────

CREATE SCHEMA IF NOT EXISTS raw_healthcare;

-- Claims source
CREATE OR REPLACE VIEW raw_healthcare.claims AS
SELECT
    claim_id,
    claim_line_id,
    patient_id,
    provider_id,
    payer_id,
    procedure_code,
    diagnosis_code_primary,
    diagnosis_code_secondary,
    service_date::date AS service_date,
    submission_date::date AS submission_date,
    billed_amount::numeric AS billed_amount,
    claim_status,
    place_of_service_code,
    _loaded_at::timestamp AS _loaded_at
FROM public.seed_raw_claims;

-- Denials source
CREATE OR REPLACE VIEW raw_healthcare.denials AS
SELECT
    denial_id,
    claim_id,
    denial_date::date AS denial_date,
    denial_reason_code,
    remark_code,
    denied_amount::numeric AS denied_amount,
    appeal_status,
    NULLIF(appeal_date, '')::date AS appeal_date,
    NULLIF(appeal_resolution_date, '')::date AS appeal_resolution_date,
    _loaded_at::timestamp AS _loaded_at
FROM public.seed_raw_denials;

-- Payments source
CREATE OR REPLACE VIEW raw_healthcare.payments AS
SELECT
    payment_id,
    claim_id,
    payer_id,
    payment_date::date AS payment_date,
    paid_amount::numeric AS paid_amount,
    allowed_amount::numeric AS allowed_amount,
    adjustment_amount::numeric AS adjustment_amount,
    patient_responsibility::numeric AS patient_responsibility,
    payment_method,
    check_eft_number,
    _loaded_at::timestamp AS _loaded_at
FROM public.seed_raw_payments;

-- Providers source
CREATE OR REPLACE VIEW raw_healthcare.providers AS
SELECT
    provider_id,
    npi,
    provider_name,
    provider_type,
    specialty,
    tax_id,
    practice_name,
    practice_state,
    is_active::boolean AS is_active,
    _loaded_at::timestamp AS _loaded_at
FROM public.seed_raw_providers;

-- Payers source
CREATE OR REPLACE VIEW raw_healthcare.payers AS
SELECT
    payer_id,
    payer_name,
    plan_type,
    payer_category,
    contract_effective_date::date AS contract_effective_date,
    NULLIF(contract_end_date, '')::date AS contract_end_date,
    contracted_rate_pct::numeric AS contracted_rate_pct,
    _loaded_at::timestamp AS _loaded_at
FROM public.seed_raw_payers;

-- Patients source
CREATE OR REPLACE VIEW raw_healthcare.patients AS
SELECT
    patient_id,
    date_of_birth::date AS date_of_birth,
    gender,
    zip_code,
    primary_payer_id,
    NULLIF(secondary_payer_id, '') AS secondary_payer_id,
    coverage_start_date::date AS coverage_start_date,
    NULLIF(coverage_end_date, '')::date AS coverage_end_date,
    _loaded_at::timestamp AS _loaded_at
FROM public.seed_raw_patients;

-- Procedures source
CREATE OR REPLACE VIEW raw_healthcare.procedures AS
SELECT
    procedure_code,
    procedure_description,
    procedure_category,
    code_type,
    standard_charge::numeric AS standard_charge,
    rvu_work::numeric AS rvu_work,
    rvu_practice::numeric AS rvu_practice,
    rvu_malpractice::numeric AS rvu_malpractice,
    _loaded_at::timestamp AS _loaded_at
FROM public.seed_raw_procedures;

-- Verify
SELECT 'claims' AS source_table, count(*) AS row_count FROM raw_healthcare.claims
UNION ALL SELECT 'denials', count(*) FROM raw_healthcare.denials
UNION ALL SELECT 'payments', count(*) FROM raw_healthcare.payments
UNION ALL SELECT 'providers', count(*) FROM raw_healthcare.providers
UNION ALL SELECT 'payers', count(*) FROM raw_healthcare.payers
UNION ALL SELECT 'patients', count(*) FROM raw_healthcare.patients
UNION ALL SELECT 'procedures', count(*) FROM raw_healthcare.procedures
ORDER BY source_table;
