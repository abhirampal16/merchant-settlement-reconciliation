{{ config(
    materialized='view',
    tags=['intermediate', 'crm', 'merchant_reference']
) }}

-- Import CTEs
with merchants as (

    select *
    from {{ ref('stg_crm__merchants') }}

),

-- Logic CTEs
legal_entity_history as (

    select
        -- Source identity
        merchant_id,

        -- Merchant legal entity attributes
        merchant_name,
        legal_entity,
        country,
        onboarded_at as valid_from,
        cast(null as timestamp) as valid_to,
        true as is_current_record,

        -- Source lineage
        updated_at,
        dbt_loaded_at,
        dbt_invocation_id,
        source_relation

    from merchants

),

-- Final CTE
final as (

    select *
    from legal_entity_history

)

select *
from final
