{{ config(
    materialized='table',
    tags=['subledger', 'audit', 'merchant_payable_reconciliation']
) }}

-- Import CTEs
with settlement_events as (

    select *
    from {{ ref('fct_merchant_settlement_events') }}

),

gl_entries as (

    select *
    from {{ ref('int_gl_merchant_payable_entries') }}

),

-- Logic CTEs
settlement_aggregates as (

    select
        accounting_date as posting_date,
        legal_entity,
        currency,
        sum(signed_net_amount) as settlement_net
    from settlement_events
    group by
        accounting_date,
        legal_entity,
        currency

),

gl_aggregates as (

    select
        posting_date,
        legal_entity,
        currency,
        sum(gl_net_amount) as gl_net
    from gl_entries
    group by
        posting_date,
        legal_entity,
        currency

),

reconciled as (

    select
        coalesce(settlement_aggregates.posting_date, gl_aggregates.posting_date) as posting_date,
        coalesce(settlement_aggregates.legal_entity, gl_aggregates.legal_entity) as legal_entity,
        coalesce(settlement_aggregates.currency, gl_aggregates.currency) as currency,

        coalesce(settlement_aggregates.settlement_net, 0) as settlement_net,
        coalesce(gl_aggregates.gl_net, 0) as gl_net,
        coalesce(settlement_aggregates.settlement_net, 0)
            - coalesce(gl_aggregates.gl_net, 0) as variance,

        case
            when coalesce(settlement_aggregates.settlement_net, 0)
                - coalesce(gl_aggregates.gl_net, 0) = 0
                then 'PASS'
            else 'FAIL'
        end as variance_status,

        case
            when settlement_aggregates.posting_date is null then 'GL_ONLY'
            when gl_aggregates.posting_date is null then 'SETTLEMENT_ONLY'
            when coalesce(settlement_aggregates.settlement_net, 0)
                - coalesce(gl_aggregates.gl_net, 0) = 0
                then 'MATCHED'
            else 'AMOUNT_VARIANCE'
        end as reconciliation_status

    from settlement_aggregates
    full outer join gl_aggregates
        on settlement_aggregates.posting_date = gl_aggregates.posting_date
        and settlement_aggregates.legal_entity = gl_aggregates.legal_entity
        and settlement_aggregates.currency = gl_aggregates.currency

),

with_audit_fields as (

    select
        {{ dbt_utils.generate_surrogate_key([
            'posting_date',
            'legal_entity',
            'currency'
        ]) }} as tieout_key,

        posting_date,
        legal_entity,
        currency,
        settlement_net,
        gl_net,
        variance,
        variance_status,
        reconciliation_status,

        {{ dbt_utils.generate_surrogate_key([
            'posting_date',
            'legal_entity',
            'currency',
            'settlement_net',
            'gl_net',
            'variance',
            'variance_status',
            'reconciliation_status'
        ]) }} as evidence_hash,

        current_timestamp as dbt_loaded_at,
        '{{ invocation_id }}' as dbt_invocation_id,
        'PROVISIONAL' as certification_status

    from reconciled

),

-- Final CTE
final as (

    select *
    from with_audit_fields

)

select *
from final
