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
        cast(event_ts as timestamp) as event_ts,
        cast(event_ts as date) as event_date,
        cast(gross_amount as numeric(18, 2)) as gross_amount,
        cast(fee_amount as numeric(18, 2)) as fee_amount,
        cast(net_amount as numeric(18, 2)) as net_amount,
        upper(cast(currency as varchar)) as currency,
        upper(cast(status as varchar)) as status,

        -- Source lineage
        cast(source_updated_at as timestamp) as source_updated_at,
        current_timestamp as dbt_loaded_at,
        '{{ invocation_id }}' as dbt_invocation_id,
        'payments_db.settlement_events' as source_relation

    from settlement_events

),

deduplicated as (

    select *
    from standardized
    qualify row_number() over (
        partition by event_id
        order by source_updated_at desc
    ) = 1

),

-- Final CTE
final as (

    select *
    from deduplicated

)

select *
from final
