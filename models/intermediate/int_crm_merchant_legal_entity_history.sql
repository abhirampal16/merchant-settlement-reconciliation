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

    /*
        Production note:
        Merchant legal entity should be modeled as an SCD Type 2 history because
        legal entity assignment can change over time and affects the reconciliation
        grain. In production, this model would be backed by a dbt snapshot or source
        history table with valid_from / valid_to ranges. Settlement events would
        join to this history point-in-time using event_ts so historical accounting
        evidence remains stable even if the current CRM record changes later.

        This repo has one current merchant record per merchant, so the
        model represents the SCD Type 2 shape without generating multiple versions.
    */

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
        source_record_fingerprint,
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
