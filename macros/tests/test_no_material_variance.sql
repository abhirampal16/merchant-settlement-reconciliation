{% test no_material_variance(model, threshold=1000) %}
{#
    Anomaly detection test: flags any single tieout row where the absolute
    variance exceeds a materiality threshold. Default threshold is $1,000.

    In production, the threshold would be set by the Controller per legal entity
    and currency. For this proof harness, a single global threshold demonstrates
    the pattern.

    This is a WARNING-severity test — material variances are investigated,
    not pipeline failures.
#}

select
    posting_date,
    legal_entity,
    currency,
    settlement_net,
    gl_net,
    variance,
    absolute_variance
from {{ model }}
where absolute_variance > {{ threshold }}

{% endtest %}
