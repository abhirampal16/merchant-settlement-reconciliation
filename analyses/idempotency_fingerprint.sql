select
    count(*) as row_count,
    md5(
        string_agg(
            tieout_key
            || '|'
            || evidence_hash
            || '|'
            || cast(dbt_loaded_at as varchar)
            || '|'
            || dbt_invocation_id,
            '||'
            order by posting_date, legal_entity, currency
        )
    ) as output_fingerprint
from {{ ref('audit_merchant_payable_tieout') }}
