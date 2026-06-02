{% test valid_reconciliation_status(model) %}

select *
from {{ model }}
where
    (
        variance = 0
        and variance_status <> 'PASS'
    )
    or (
        variance <> 0
        and variance_status <> 'FAIL'
    )
    or (
        has_settlement_activity = false
        and has_gl_activity = true
        and reconciliation_status <> 'GL_ONLY'
    )
    or (
        has_settlement_activity = true
        and has_gl_activity = false
        and reconciliation_status <> 'SETTLEMENT_ONLY'
    )
    or (
        has_settlement_activity = true
        and has_gl_activity = true
        and variance = 0
        and reconciliation_status <> 'MATCHED'
    )
    or (
        has_settlement_activity = true
        and has_gl_activity = true
        and variance <> 0
        and reconciliation_status <> 'AMOUNT_VARIANCE'
    )

{% endtest %}
