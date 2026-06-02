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
        sum(signed_net_amount) as settlement_net,
        count(*) as settlement_event_count,
        min(event_ts) as settlement_min_event_ts,
        max(event_ts) as settlement_max_event_ts,
        max(source_updated_at) as latest_settlement_source_updated_at
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
        sum(gl_net_amount) as gl_net,
        count(*) as gl_entry_count,
        min(created_at) as gl_min_created_at,
        max(created_at) as gl_max_created_at,
        max(created_at) as latest_gl_created_at
    from gl_entries
    group by
        posting_date,
        legal_entity,
        currency

),

side_by_side as (

    select
        coalesce(settlement_aggregates.posting_date, gl_aggregates.posting_date) as posting_date,
        coalesce(settlement_aggregates.legal_entity, gl_aggregates.legal_entity) as legal_entity,
        coalesce(settlement_aggregates.currency, gl_aggregates.currency) as currency,

        settlement_aggregates.posting_date is not null as has_settlement_activity,
        gl_aggregates.posting_date is not null as has_gl_activity,

        coalesce(settlement_aggregates.settlement_net, 0) as settlement_net,
        coalesce(gl_aggregates.gl_net, 0) as gl_net,

        coalesce(settlement_aggregates.settlement_event_count, 0) as settlement_event_count,
        coalesce(gl_aggregates.gl_entry_count, 0) as gl_entry_count,

        settlement_aggregates.settlement_min_event_ts,
        settlement_aggregates.settlement_max_event_ts,
        gl_aggregates.gl_min_created_at,
        gl_aggregates.gl_max_created_at,
        settlement_aggregates.latest_settlement_source_updated_at,
        gl_aggregates.latest_gl_created_at

    from settlement_aggregates
    full outer join gl_aggregates
        on settlement_aggregates.posting_date = gl_aggregates.posting_date
        and settlement_aggregates.legal_entity = gl_aggregates.legal_entity
        and settlement_aggregates.currency = gl_aggregates.currency

),

classified as (

    select
        *,
        settlement_net - gl_net as variance,
        abs(settlement_net - gl_net) as absolute_variance,

        case
            when settlement_net - gl_net = 0 then 'NO_VARIANCE'
            when settlement_net - gl_net > 0 then 'SETTLEMENT_GREATER_THAN_GL'
            else 'GL_GREATER_THAN_SETTLEMENT'
        end as variance_direction,

        case
            when gl_net = 0 then null
            else abs(settlement_net - gl_net) / nullif(abs(gl_net), 0)
        end as variance_pct_of_gl,

        case
            when settlement_net - gl_net = 0 then 'PASS'
            else 'FAIL'
        end as variance_status,

        case
            when not has_settlement_activity and has_gl_activity then 'GL_ONLY'
            when has_settlement_activity and not has_gl_activity then 'SETTLEMENT_ONLY'
            when settlement_net - gl_net = 0 then 'MATCHED'
            else 'AMOUNT_VARIANCE'
        end as reconciliation_status

    from side_by_side

),

triage_context as (

    select
        *,
        reconciliation_status <> 'MATCHED' as needs_investigation,

        case
            when reconciliation_status in ('GL_ONLY', 'SETTLEMENT_ONLY') then 'HIGH'
            when absolute_variance >= 100 then 'HIGH'
            when absolute_variance > 0 then 'MEDIUM'
            else 'LOW'
        end as investigation_priority,

        case
            when reconciliation_status = 'GL_ONLY'
                then 'GL posting exists without matching settlement activity at the posting date, legal entity, and currency grain.'
            when reconciliation_status = 'SETTLEMENT_ONLY'
                then 'Settlement activity exists without matching Merchant Payable GL posting at the posting date, legal entity, and currency grain.'
            when reconciliation_status = 'AMOUNT_VARIANCE'
                then 'Both settlement and GL activity exist, but the net amounts differ.'
            else 'Settlement activity matches Merchant Payable GL posting at the reconciliation grain.'
        end as deterministic_root_cause_hint

    from classified

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
        absolute_variance,
        variance_direction,
        variance_pct_of_gl,
        variance_status,
        reconciliation_status,

        has_settlement_activity,
        has_gl_activity,
        settlement_event_count,
        gl_entry_count,
        settlement_min_event_ts,
        settlement_max_event_ts,
        gl_min_created_at,
        gl_max_created_at,
        latest_settlement_source_updated_at,
        latest_gl_created_at,

        needs_investigation,
        investigation_priority,
        deterministic_root_cause_hint,

        {{ dbt_utils.generate_surrogate_key([
            'posting_date',
            'legal_entity',
            'currency',
            'settlement_net',
            'gl_net',
            'variance',
            'variance_status',
            'reconciliation_status',
            'has_settlement_activity',
            'has_gl_activity',
            'settlement_event_count',
            'gl_entry_count',
            'deterministic_root_cause_hint'
        ]) }} as evidence_hash,

        current_timestamp as dbt_loaded_at,
        '{{ invocation_id }}' as dbt_invocation_id,
        'PROVISIONAL' as certification_status

    from triage_context

),

-- Final CTE
final as (

    select *
    from with_audit_fields

)

select *
from final
