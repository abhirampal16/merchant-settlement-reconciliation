# merchant-settlement-reconciliation

Local dbt project for reconciling merchant settlement events to Merchant Payable
GL postings. The project uses DuckDB for take-home reproducibility so reviewers
can run the synthetic seed data without cloud warehouse credentials.

## Run the Pipeline

```powershell
dbt build --no-version-check --profiles-dir .
```

Expected result:

```text
PASS=90 WARN=0 ERROR=0 SKIP=0 TOTAL=90
```

## Show Reconciliation Output

```powershell
dbt show --no-version-check --profiles-dir . --limit 100 --inline "select posting_date, legal_entity, currency, settlement_net, gl_net, variance, reconciliation_status, investigation_priority, evidence_hash from main_subledger.audit_merchant_payable_tieout order by posting_date, legal_entity, currency"
```

## Prove Idempotency

Run two builds over the same seed data and compare the final output fingerprint:

```powershell
dbt build --no-version-check --profiles-dir .
dbt show --no-version-check --profiles-dir . --select idempotency_fingerprint

dbt build --no-version-check --profiles-dir .
dbt show --no-version-check --profiles-dir . --select idempotency_fingerprint
```

The `row_count` and `output_fingerprint` should be identical across both runs.
This proves the final reconciliation output is stable when input data is
unchanged.

Captured evidence from a local DuckDB run is stored under `evidence/`.
