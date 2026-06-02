{{ config(
    materialized='table',
    tags=['subledger', 'fact', 'settlement_reconciliation']
) }}

-- Import CTEs
with settlement_events_signed as (

    select *
    from {{ ref('int_settlement_events_signed') }}

),

-- Logic CTEs
canonical_settlement_events as (

    select
        -- Canonical fact identity
        {{ generate_evidence_hash(['event_id']) }} as settlement_event_key,
        event_id,
        settlement_id,

        -- Business keys and accounting dimensions
        merchant_id,
        legal_entity,
        accounting_date,
        currency,

        -- Event attributes
        event_type,
        event_ts,
        gross_amount,
        fee_amount,
        net_amount,
        signed_net_amount,
        status,

        -- Source and audit lineage
        source_updated_at,
        source_relation,
        dbt_loaded_at,
        dbt_invocation_id,

        {{ generate_evidence_hash([
            'event_id',
            'settlement_id',
            'merchant_id',
            'legal_entity',
            'accounting_date',
            'currency',
            'event_type',
            'net_amount',
            'signed_net_amount',
            'source_updated_at'
        ]) }} as record_hash

    from settlement_events_signed

),

-- Final CTE
final as (

    select *
    from canonical_settlement_events

)

select *
from final
