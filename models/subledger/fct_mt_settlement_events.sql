{{ config(
    materialized='incremental',
    incremental_strategy='merge',
    unique_key='settlement_event_key',
    cluster_by=['accounting_date'],
    tags=['subledger', 'fact', 'settlement_reconciliation']
) }}

/*
    Incremental strategy:
    - Merge on settlement_event_key (deterministic hash of event_id)
    - Cluster on accounting_date for downstream tieout partition pruning
    - 16-day lookback on source_updated_at captures late-arriving events
      and CDC replays without rescanning the full history
    - source_updated_at is the arrival watermark (when we learned about
      the event), not accounting_date (when it economically occurred)
*/

-- Import CTEs
with settlement_events_signed as (

    select *
    from {{ ref('int_mt_settlement_events_signed') }}

    {% if is_incremental() %}
    where source_updated_at >= (
        select dateadd(day, -16, max(source_updated_at))
        from {{ this }}
    )
    {% endif %}

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
