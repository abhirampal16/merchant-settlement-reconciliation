{{ config(
    materialized='view',
    tags=['intermediate', 'netsuite', 'merchant_payable_reconciliation']
) }}

-- Import CTEs
with journal_entries as (

    select *
    from {{ ref('stg_netsuite__journal_entries') }}

),

-- Logic CTEs
merchant_payable_entries as (

    select
        -- Source identity
        je_id,

        -- Reconciliation grain
        posting_date,
        legal_entity,
        currency,

        -- GL attributes
        account,
        debit_amount,
        credit_amount,
        credit_amount - debit_amount as gl_net_amount,
        memo,

        -- Source lineage
        created_at,
        source_record_fingerprint,
        source_relation

    from journal_entries
    where account = 2100

),

-- Final CTE
final as (

    select *
    from merchant_payable_entries

)

select *
from final
