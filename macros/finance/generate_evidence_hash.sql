{% macro generate_evidence_hash(columns) %}
    md5(
        {%- for column in columns -%}
            coalesce(cast({{ column }} as varchar), '_dbt_surrogate_key_null_')
            {%- if not loop.last %} || '-' || {% endif -%}
        {%- endfor -%}
    )
{% endmacro %}
