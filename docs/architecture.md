# Architecture & Data Model Brief

## Objective
Build a governed merchant settlement subledger that answers: for a posting day, legal entity, and currency, do finalized net settlements reconcile to NetSuite Merchant Payable account 2100?

## Architecture Decision
Use a hybrid pattern: CDC into Snowflake for source freshness, scheduled dbt runs for accounting certification.

Tradeoffs:
- Correctness: dbt owns settlement sign logic, dedupe, grain, and evidence hashes in version-controlled SQL.
- Latency: CDC keeps raw data current; certification waits for a controlled run so close output is stable.
- Cost: batch aggregation avoids always-on streaming reconciliation over ~50M settlement rows/day.
- Auditability: every certified result can be rerun from raw history, code version, and deterministic hashes.

Streaming can still power operational alerts, but it should not be the system of record for close evidence.

## Platform Layers
| Layer | Production component | Purpose |
| --- | --- | --- |
| Source systems | `payments_db.settlement_events`, `netsuite.journal_entries`, `crm.merchants` | Settlement events, GL postings, merchant reference data |
| Raw landing | CDC / connector-managed Snowflake tables | Preserve source history and support replay |
| dbt staging | `stg_*` models | Standardize types, casing, source timestamps, and dedupe latest source versions |
| dbt intermediate | `int_mt_settlement_events_signed`, `int_ns_merchant_payable_entries` | Apply sign logic, account 2100 filtering, debit/credit normalization |
| Canonical fact | `fct_mt_settlement_events` | One row per accounting-relevant settlement event |
| Tie-out | `fct_mt_merchant_payable_tieout` | One row per `posting_date`, `legal_entity`, `currency` |
| Evidence | Certified audit storage | Retain run artifacts, hashes, and replay metadata |

The local repo uses DuckDB and seed-backed sources as a reproducible proof harness for this production shape.

## Model Rules
- Only `FINAL` settlement events enter certified reconciliation.
- `SETTLED` and `ADJUSTED` keep source sign; `REVERSED` and `CHARGEBACK` are negative signed events.
- Staging treats source timestamps as UTC and exposes explicit `*_utc` lineage fields.
- Settlement `accounting_date` ties to NetSuite `posting_date`.
- The canonical fact key is derived from stable `event_id`; if that assumption fails, use the settlement business key instead.
- Late data is handled by reprocessing a 16-day window for the 14-day late-arriving source.

## AI-Assisted Variance Triage
The tie-out includes deterministic triage context for reviewers or LLM-assisted investigation. It does not certify results automatically.

Columns: `needs_investigation`, `investigation_priority`, `deterministic_root_cause_hint`, `reconciliation_status`, `variance_direction`, `absolute_variance`, `evidence_hash`.
