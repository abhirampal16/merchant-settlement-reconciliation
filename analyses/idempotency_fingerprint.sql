select
    count(*) as row_count,
    md5(
        string_agg(
            tieout_key
            || '|'
            || evidence_hash
            || '|'
            || cast(latest_source_activity_at as varchar)
            || '|'
            || tieout_fingerprint,
            '||'
            order by posting_date, legal_entity, currency
        )
    ) as output_fingerprint
from {{ ref('audit_merchant_payable_tieout') }}
