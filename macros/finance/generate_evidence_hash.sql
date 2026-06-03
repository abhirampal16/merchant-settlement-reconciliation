{% macro generate_evidence_hash(columns) %}
    sha256(
        {%- for column in columns -%}
            coalesce(trim(upper(cast({{ column }} as varchar))), '_evidence_hash_null_')
            {%- if not loop.last %} || '|' || {% endif -%}
        {%- endfor -%}
    )
{% endmacro %}
