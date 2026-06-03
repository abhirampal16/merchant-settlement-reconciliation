# merchant-settlement-reconciliation

Full codebase: https://github.com/abhirampal16/merchant-settlement-reconciliation

Local dbt project for reconciling merchant settlement events to Merchant Payable
GL postings. The project uses DuckDB for take-home reproducibility so reviewers
can run the synthetic seed data without cloud warehouse credentials.

## Deliverable 2: dbt Tie-Out

Primary files:

- `models/subledger/audit_merchant_payable_tieout.sql`
- `models/subledger/subledger.yml`
- `macros/tests/test_valid_reconciliation_status.sql`

The tie-out emits one row per `posting_date`, `legal_entity`, and `currency`.
It compares signed settlement net activity to NetSuite Merchant Payable account
2100, surfaces business exceptions, and produces a deterministic `evidence_hash`.

## Run the Pipeline

```powershell
dbt build --no-version-check --profiles-dir .
```

Expected result:

```text
PASS=112 WARN=0 ERROR=0 SKIP=0 TOTAL=112
```

## Show Reconciliation Output

```powershell
dbt show --no-version-check --profiles-dir . --limit 100 --inline "select posting_date, legal_entity, currency, settlement_net, gl_net, variance, reconciliation_status, investigation_priority, evidence_hash from main_subledger.audit_merchant_payable_tieout order by posting_date, legal_entity, currency"
```

Sample output from the included dummy data:

| posting_date | legal_entity | currency | settlement_net | gl_net | variance | reconciliation_status | priority |
| --- | --- | --- | ---: | ---: | ---: | --- | --- |
| 2026-05-01 | FinCo Canada | CAD | 725.00 | 725.00 | 0.00 | MATCHED | LOW |
| 2026-05-01 | FinCo UK | GBP | 300.00 | 300.00 | 0.00 | MATCHED | LOW |
| 2026-05-01 | FinCo US | USD | 1300.00 | 1300.00 | 0.00 | MATCHED | LOW |
| 2026-05-02 | FinCo Canada | CAD | 800.00 | 750.00 | 50.00 | AMOUNT_VARIANCE | MEDIUM |
| 2026-05-02 | FinCo UK | GBP | 0.00 | 150.00 | -150.00 | GL_ONLY | HIGH |

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
