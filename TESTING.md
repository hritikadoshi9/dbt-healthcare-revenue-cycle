# ──────────────────────────────────────────────────────────────
# LOCAL TESTING GUIDE
# ──────────────────────────────────────────────────────────────
#
# To test this package locally using the synthetic seed data:
#
# 1. Install PostgreSQL (or use Docker):
#    docker run -d --name dbt-test -p 5432:5432 \
#      -e POSTGRES_USER=dbt -e POSTGRES_PASSWORD=dbt -e POSTGRES_DB=dbt \
#      postgres:15
#
# 2. Create a profiles.yml in ~/.dbt/:
#
#    healthcare_revenue_cycle:
#      target: dev
#      outputs:
#        dev:
#          type: postgres
#          host: localhost
#          port: 5432
#          user: dbt
#          pass: dbt
#          dbname: dbt
#          schema: public
#          threads: 4
#
# 3. Load the synthetic data as source tables:
#    dbt seed
#
# 4. To use seed tables as sources, rename the seed tables
#    to match the source contract. Run this SQL after seeding:
#
#    -- Create the raw_healthcare schema
#    CREATE SCHEMA IF NOT EXISTS raw_healthcare;
#
#    -- Map seed tables to source tables
#    CREATE OR REPLACE VIEW raw_healthcare.claims AS SELECT * FROM public.seed_raw_claims;
#    CREATE OR REPLACE VIEW raw_healthcare.denials AS SELECT * FROM public.seed_raw_denials;
#    CREATE OR REPLACE VIEW raw_healthcare.payments AS SELECT * FROM public.seed_raw_payments;
#    CREATE OR REPLACE VIEW raw_healthcare.providers AS SELECT * FROM public.seed_raw_providers;
#    CREATE OR REPLACE VIEW raw_healthcare.payers AS SELECT * FROM public.seed_raw_payers;
#    CREATE OR REPLACE VIEW raw_healthcare.patients AS SELECT * FROM public.seed_raw_patients;
#    CREATE OR REPLACE VIEW raw_healthcare.procedures AS SELECT * FROM public.seed_raw_procedures;
#
# 5. Run the full pipeline:
#    dbt build --full-refresh
#
# 6. Generate and serve docs:
#    dbt docs generate
#    dbt docs serve
#
# ──────────────────────────────────────────────────────────────
