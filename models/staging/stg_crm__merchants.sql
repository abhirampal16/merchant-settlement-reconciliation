{{ config(
    materialized='view',
    tags=['staging', 'crm', 'merchant_reference']
) }}

-- Import CTEs
with merchants as (

    select *
    from {{ ref('merchants') }}

),

-- Logic CTEs
standardized as (

    select
        -- Source identity
        cast(merchant_id as varchar) as merchant_id,

        -- Merchant attributes
        cast(merchant_name as varchar) as merchant_name,
        cast(legal_entity as varchar) as legal_entity,
        upper(cast(country as varchar)) as country,
        cast(onboarded_at as timestamp) as onboarded_at,

        -- Source lineage
        cast(updated_at as timestamp) as updated_at,
        current_timestamp as dbt_loaded_at,
        '{{ invocation_id }}' as dbt_invocation_id,
        'crm.merchants' as source_relation

    from merchants

),

-- Final CTE
final as (

    select *
    from standardized

)

select *
from final
