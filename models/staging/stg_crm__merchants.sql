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
        cast(onboarded_at as timestamp) as onboarded_at_utc,
        cast(onboarded_at as timestamp) as onboarded_at,

        -- Source lineage
        cast(updated_at as timestamp) as updated_at_utc,
        cast(updated_at as timestamp) as updated_at,
        'UTC' as source_timezone,
        'crm.merchants' as source_relation

    from merchants

),

with_deterministic_lineage as (

    select
        *,
        {{ generate_evidence_hash([
            'merchant_id',
            'merchant_name',
            'legal_entity',
            'country',
            'onboarded_at_utc',
            'updated_at_utc'
        ]) }} as source_record_fingerprint
    from standardized

),

deduplicated as (

    select *
    from with_deterministic_lineage
    qualify row_number() over (
        partition by merchant_id
        order by updated_at desc, legal_entity, merchant_name, country
    ) = 1

),

-- Final CTE
final as (

    select *
    from deduplicated

)

select *
from final
