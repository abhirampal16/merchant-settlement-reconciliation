{{ config(
    materialized='view',
    tags=['staging', 'payments', 'settlement_reconciliation']
) }}

-- Import CTEs
with settlement_events as (

    select *
    from {{ ref('settlement_events') }}

),

-- Logic CTEs
standardized as (

    select
        -- Source identity
        cast(event_id as varchar) as event_id,
        cast(settlement_id as varchar) as settlement_id,
        cast(merchant_id as varchar) as merchant_id,

        -- Settlement event attributes
        upper(cast(event_type as varchar)) as event_type,
        cast(event_ts as timestamp) as event_ts_utc,
        cast(event_ts as timestamp) as event_ts,
        cast(cast(event_ts as timestamp) as date) as event_date,
        cast(gross_amount as numeric(18, 2)) as gross_amount,
        cast(fee_amount as numeric(18, 2)) as fee_amount,
        cast(net_amount as numeric(18, 2)) as net_amount,
        upper(cast(currency as varchar)) as currency,
        upper(cast(status as varchar)) as status,

        -- Source lineage
        cast(source_updated_at as timestamp) as source_updated_at_utc,
        cast(source_updated_at as timestamp) as source_updated_at,
        cast(source_updated_at as timestamp) as dbt_loaded_at,
        'UTC' as source_timezone,
        'payments_db.settlement_events' as source_relation

    from settlement_events

),

with_deterministic_lineage as (

    select
        *,
        {{ generate_evidence_hash([
            'event_id',
            'settlement_id',
            'merchant_id',
            'event_type',
            'event_ts_utc',
            'gross_amount',
            'fee_amount',
            'net_amount',
            'currency',
            'status',
            'source_updated_at_utc'
        ]) }} as dbt_invocation_id
    from standardized

),

deduplicated as (

    select *
    from with_deterministic_lineage
    qualify row_number() over (
        partition by event_id
        order by source_updated_at desc, settlement_id, merchant_id, event_ts desc
    ) = 1

),

-- Final CTE
final as (

    select *
    from deduplicated

)

select *
from final
