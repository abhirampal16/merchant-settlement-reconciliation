{% macro create_audit_merchant_payable_run_log_table() %}
    create table if not exists {{ target.schema }}_subledger.audit_merchant_payable_run_log (
        run_log_id varchar,
        dbt_invocation_id varchar,
        run_started_at_utc timestamp,
        run_completed_at_utc timestamp,
        target_name varchar,
        target_schema varchar,
        model_name varchar,
        model_relation varchar,
        row_count integer,
        matched_count integer,
        exception_count integer,
        amount_variance_count integer,
        gl_only_count integer,
        settlement_only_count integer,
        output_fingerprint varchar,
        dbt_result_status varchar,
        created_at_utc timestamp
    )
{% endmacro %}

{% macro insert_audit_merchant_payable_run_log(results) %}
    {% set ns = namespace(audit_model_ran=false, audit_status='SKIPPED') %}

    {% for result in results %}
        {% if result.node is defined and result.node.name == 'audit_merchant_payable_tieout' %}
            {% set ns.audit_status = result.status | upper %}
            {% if result.status == 'success' %}
                {% set ns.audit_model_ran = true %}
            {% endif %}
        {% endif %}
    {% endfor %}

    {% if ns.audit_model_ran %}
        insert into {{ target.schema }}_subledger.audit_merchant_payable_run_log (
            run_log_id,
            dbt_invocation_id,
            run_started_at_utc,
            run_completed_at_utc,
            target_name,
            target_schema,
            model_name,
            model_relation,
            row_count,
            matched_count,
            exception_count,
            amount_variance_count,
            gl_only_count,
            settlement_only_count,
            output_fingerprint,
            dbt_result_status,
            created_at_utc
        )
        select
            sha256('{{ invocation_id }}|audit_merchant_payable_tieout') as run_log_id,
            '{{ invocation_id }}' as dbt_invocation_id,
            cast('{{ run_started_at.strftime("%Y-%m-%d %H:%M:%S") }}' as timestamp) as run_started_at_utc,
            current_timestamp as run_completed_at_utc,
            '{{ target.name }}' as target_name,
            '{{ target.schema }}' as target_schema,
            'audit_merchant_payable_tieout' as model_name,
            '{{ target.schema }}_subledger.audit_merchant_payable_tieout' as model_relation,
            row_count,
            matched_count,
            exception_count,
            amount_variance_count,
            gl_only_count,
            settlement_only_count,
            output_fingerprint,
            '{{ ns.audit_status }}' as dbt_result_status,
            current_timestamp as created_at_utc
        from (
            select
                count(*) as row_count,
                sum(case when reconciliation_status = 'MATCHED' then 1 else 0 end) as matched_count,
                sum(case when reconciliation_status <> 'MATCHED' then 1 else 0 end) as exception_count,
                sum(case when reconciliation_status = 'AMOUNT_VARIANCE' then 1 else 0 end) as amount_variance_count,
                sum(case when reconciliation_status = 'GL_ONLY' then 1 else 0 end) as gl_only_count,
                sum(case when reconciliation_status = 'SETTLEMENT_ONLY' then 1 else 0 end) as settlement_only_count,
                sha256(
                    coalesce(
                        string_agg(
                            tieout_key
                            || '|'
                            || evidence_hash
                            || '|'
                            || cast(dbt_loaded_at as varchar)
                            || '|'
                            || dbt_invocation_id,
                            '||'
                            order by posting_date, legal_entity, currency
                        ),
                        ''
                    )
                ) as output_fingerprint
            from {{ target.schema }}_subledger.audit_merchant_payable_tieout
        ) as run_summary
    {% else %}
        select 1 as audit_merchant_payable_run_log_skipped
    {% endif %}
{% endmacro %}
