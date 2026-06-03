# Controls

| Control | What it checks | Implementation |
| --- | --- | --- |
| Source contract | Required keys, event statuses, event types, account fields, timestamps | dbt source and column tests |
| Relationship / grain | One tie-out row per `posting_date`, `legal_entity`, `currency` | `unique_combination_of_columns` and key tests |
| Reconciliation | Settlement net equals GL net, or the row is classified as an exception | `valid_reconciliation_status` custom generic test |
| Freshness / late data | Source data lands within expected windows; 14-day late data is reprocessed | Source freshness plus 16-day production reprocess window |
| Backfill safety | Certified periods are protected from routine reruns | Production approval flow, immutable evidence, and replay comparison |

Business variances are not hidden as pipeline failures. They are surfaced with status, priority, root-cause hint, and evidence hash for Accounting review.
