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
        cast(created_at as timestamp) as created_at,
        current_timestamp as dbt_loaded_at,
        '{{ invocation_id }}' as dbt_invocation_id,
        'netsuite.journal_entries' as source_relation

    from journal_entries

),

-- Final CTE
final as (

    select *
    from standardized

)

select *
from final
