# Merchant Settlement Reconciliation

A dbt proof harness that reconciles merchant settlement events to NetSuite Merchant Payable (GL account 2100) by posting date, legal entity, and currency. Uses DuckDB and synthetic seed data so reviewers can run the full pipeline locally without cloud warehouse credentials.

> **Note:** This is a reproducible proof of reconciliation logic, not a production deployment. The models are production-shaped (incremental merge, evidence hashing, audit lineage) but run against synthetic data on DuckDB. Production targets Snowflake with CDC source ingestion.

## Prerequisites

- **Python** 3.9+
- **pip** (Python package manager)
- **Git**

## Installation

```bash
git clone https://github.com/abhirampal16/merchant-settlement-reconciliation.git
cd merchant-settlement-reconciliation

pip install dbt-core dbt-duckdb
```

No additional dbt packages required (`packages.yml` is empty).

## Quick Start

```bash
# Build everything: seeds, models, tests
dbt build --no-version-check --profiles-dir .

# View reconciliation output
dbt show --no-version-check --profiles-dir . --limit 100 --inline \
  "select posting_date, legal_entity, currency, settlement_net, gl_net, variance,
   reconciliation_status, investigation_priority, evidence_hash
   from main_subledger.fct_mt_merchant_payable_tieout
   order by posting_date, legal_entity, currency"
```

Expected: `PASS=112 WARN=0 ERROR=0 SKIP=0 TOTAL=112`

## Project Structure

```
├── models/
│   ├── staging/                          # Standardize, type-cast, deduplicate
│   │   ├── stg_payments__settlement_events.sql
│   │   ├── stg_netsuite__journal_entries.sql
│   │   ├── stg_crm__merchants.sql
│   │   └── staging.yml                   # Source definitions, tests, docs
│   │
│   ├── intermediate/                     # Business logic & enrichment
│   │   ├── int_mt_settlement_events_signed.sql   # Sign logic, FINAL filter, legal entity join
│   │   ├── int_ns_merchant_payable_entries.sql    # Account 2100 filter, GL normalization
│   │   └── int_crm_merchant_legal_entity_history.sql  # SCD2 shape (placeholder)
│   │
│   └── subledger/                        # Certified reconciliation output
│       ├── fct_mt_settlement_events.sql         # One row per settlement event (incremental merge)
│       ├── fct_mt_merchant_payable_tieout.sql  # Tie-out at (posting_date, legal_entity, currency)
│       └── subledger.yml                 # Tests, docs, meta
│
├── macros/
│   ├── finance/
│   │   ├── generate_evidence_hash.sql         # Deterministic SHA256 for audit lineage
│   │   ├── settlement_sign_logic.sql          # SETTLED/REVERSED/CHARGEBACK/ADJUSTED sign rules
│   │   └── audit_merchant_payable_run_log.sql # Run-level tracking & output fingerprint
│   └── tests/
│       ├── test_valid_reconciliation_status.sql     # Reconciliation logic consistency
│       ├── test_unique_combination_of_columns.sql   # Grain uniqueness enforcement
│       └── test_no_material_variance.sql            # (stub)
│
├── seeds/                                # Synthetic source data
│   ├── settlement_events.csv             # 12 events across 3 currencies
│   ├── journal_entries.csv               # 7 GL postings to account 2100
│   └── merchants.csv                     # 5 merchants across 3 legal entities
│
├── analyses/
│   └── idempotency_fingerprint.sql       # Replay stability proof
│
├── evidence/                             # Captured run artifacts (build logs, fingerprints)
├── notebooks/
│   └── final_reconciliation_output.ipynb # Pandas viewer for tieout results
├── docs/                                 # Architecture, controls, SOX evidence docs
│
├── dbt_project.yml
├── profiles.yml                          # DuckDB local profile
└── packages.yml                          # No external packages
```

## Data Flow

```
Seeds (synthetic source data)
  → Staging        Standardize types, deduplicate by primary key
  → Intermediate   Apply sign logic, filter account 2100, resolve legal entity
  → Subledger
      → fct_mt_settlement_events             Event-level fact (incremental merge)
      → fct_mt_merchant_payable_tieout     Grain-level reconciliation (full outer join)
```

## Reconciliation Output

The tieout produces one row per (posting_date, legal_entity, currency):

| posting_date | legal_entity | currency | settlement_net | gl_net | variance | status | priority |
|---|---|---|---:|---:|---:|---|---|
| 2026-05-01 | FinCo Canada | CAD | 725.00 | 725.00 | 0.00 | MATCHED | LOW |
| 2026-05-01 | FinCo UK | GBP | 300.00 | 300.00 | 0.00 | MATCHED | LOW |
| 2026-05-01 | FinCo US | USD | 1300.00 | 1300.00 | 0.00 | MATCHED | LOW |
| 2026-05-02 | FinCo Canada | CAD | 800.00 | 750.00 | 50.00 | AMOUNT_VARIANCE | MEDIUM |
| 2026-05-02 | FinCo UK | GBP | 0.00 | 150.00 | -150.00 | GL_ONLY | HIGH |
| 2026-05-02 | FinCo US | USD | 300.00 | 300.00 | 0.00 | MATCHED | LOW |

## Proving Idempotency

```bash
dbt build --no-version-check --profiles-dir .
dbt show --no-version-check --profiles-dir . --select idempotency_fingerprint

dbt build --no-version-check --profiles-dir .
dbt show --no-version-check --profiles-dir . --select idempotency_fingerprint
```

`row_count` and `output_fingerprint` should match across both runs.
