# SOX Evidence Package

## Control
Daily Merchant Payable reconciliation: finalized settlement activity must tie to NetSuite account 2100 by `posting_date`, `legal_entity`, and `currency`.

## Ownership
- Owner: Finance Data Platform
- Frequency: Daily by 08:00 local close calendar
- Materiality threshold: 0.00 for this assessment
- Escalation: Finance Ops investigates; Accounting owns certification

## Artifact
Per run, produce `fct_mt_merchant_payable_tieout` rows with:

`posting_date`, `legal_entity`, `currency`, `settlement_net`, `gl_net`, `variance`, `variance_status`, `reconciliation_status`, `needs_investigation`, `investigation_priority`, `deterministic_root_cause_hint`, `evidence_hash`, `dbt_loaded_at`, `dbt_invocation_id`, `certification_status`.

Run-level control execution is captured in append-only table `audit_merchant_payable_run_log` with:

`run_log_id`, `dbt_invocation_id`, `run_started_at_utc`, `run_completed_at_utc`, `target_name`, `target_schema`, `model_name`, `model_relation`, `row_count`, `matched_count`, `exception_count`, `amount_variance_count`, `gl_only_count`, `settlement_only_count`, `output_fingerprint`, `dbt_result_status`, `created_at_utc`.

The local proof stores captured run output under `evidence/`; production stores certified extracts and dbt artifacts in immutable audit storage.

## Replay Guarantee
Evidence hashes exclude volatile runtime values. Re-running unchanged inputs should reproduce the same row count and output fingerprint.

## Failure Response
Rows with `GL_ONLY`, `SETTLEMENT_ONLY`, or `AMOUNT_VARIANCE` remain in the evidence table, are prioritized for review, and require documented resolution before final period certification.
