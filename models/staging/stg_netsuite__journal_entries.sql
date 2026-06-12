{{ config(
    materialized='view',
    tags=['staging', 'netsuite', 'merchant_payable_reconciliation']
) }}

-- Import CTEs
with journal_entries as (

    select *
    from {{ ref('journal_entries') }}

),

-- Logic CTEs
standardized as (

    select
        -- Source identity
        cast(je_id as varchar) as je_id,

        -- GL posting attributes
        cast(posting_date as date) as posting_date,
        cast(account as integer) as account,
        cast(entity as varchar) as legal_entity,
        cast(debit as numeric(18, 2)) as debit_amount,
        cast(credit as numeric(18, 2)) as credit_amount,
        upper(cast(currency as varchar)) as currency,
        cast(memo as varchar) as memo,

        -- Source lineage
        cast(created_at as timestamp) as created_at_utc,
        cast(created_at as timestamp) as created_at,
        'UTC' as source_timezone,
        'netsuite.journal_entries' as source_relation

    from journal_entries

),

with_deterministic_lineage as (

    select
        *,
        {{ generate_evidence_hash([
            'je_id',
            'posting_date',
            'account',
            'legal_entity',
            'debit_amount',
            'credit_amount',
            'currency',
            'memo',
            'created_at_utc'
        ]) }} as source_record_fingerprint
    from standardized

),

deduplicated as (

    select *
    from with_deterministic_lineage
    qualify row_number() over (
        partition by je_id
        order by created_at desc, posting_date desc, account, legal_entity, currency
    ) = 1

),

-- Final CTE
final as (

    select *
    from deduplicated

)

select *
from final
