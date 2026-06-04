{{ config(
    materialized='view',
    tags=['intermediate', 'payments', 'settlement_reconciliation']
) }}

-- Import CTEs
with settlement_events as (

    select *
    from {{ ref('stg_payments__settlement_events') }}

),

merchants as (

    select *
    from {{ ref('stg_crm__merchants') }}

),

-- Logic CTEs
final_settlement_events as (

    select *
    from settlement_events
    where status = 'FINAL'

),

settlement_events_with_legal_entity as (

    select
        final_settlement_events.event_id,
        final_settlement_events.settlement_id,
        final_settlement_events.merchant_id,
        merchants.legal_entity,
        final_settlement_events.event_type,
        final_settlement_events.event_ts,
        final_settlement_events.event_date as accounting_date,
        final_settlement_events.gross_amount,
        final_settlement_events.fee_amount,
        final_settlement_events.net_amount,
        {{ settlement_sign_logic(
            'final_settlement_events.event_type',
            'final_settlement_events.net_amount'
        ) }} as signed_net_amount,
        final_settlement_events.currency,
        final_settlement_events.status,
        final_settlement_events.source_updated_at,
        final_settlement_events.dbt_loaded_at,
        final_settlement_events.dbt_invocation_id,
        final_settlement_events.source_relation

    from final_settlement_events
    left join merchants
        on final_settlement_events.merchant_id = merchants.merchant_id

),

-- Final CTE
final as (

    select *
    from settlement_events_with_legal_entity

)

select *
from final
