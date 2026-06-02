{% macro settlement_sign_logic(event_type, net_amount) %}
    case
        when {{ event_type }} = 'SETTLED'
            then {{ net_amount }}
        when {{ event_type }} in ('REVERSED', 'CHARGEBACK')
            then -1 * abs({{ net_amount }})
        when {{ event_type }} = 'ADJUSTED'
            then {{ net_amount }}
    end
{% endmacro %}
