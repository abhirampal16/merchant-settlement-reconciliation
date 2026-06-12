{% test exception_rate_anomaly(model, max_exception_pct=50) %}
{#
    Anomaly detection test: flags when the percentage of non-MATCHED rows
    exceeds a threshold of total tieout rows. A sudden spike in exception
    rate signals upstream data quality issues — broken CDC feed, missing
    GL batch, or source schema drift.

    Default threshold is 50%. In production, calibrate this to the rolling
    7-day average exception rate + 2 standard deviations.
#}

with summary as (

    select
        count(*) as total_rows,
        sum(case when reconciliation_status <> 'MATCHED' then 1 else 0 end) as exception_rows
    from {{ model }}

)

select
    total_rows,
    exception_rows,
    round(100.0 * exception_rows / nullif(total_rows, 0), 2) as exception_pct,
    {{ max_exception_pct }} as threshold_pct
from summary
where 100.0 * exception_rows / nullif(total_rows, 0) > {{ max_exception_pct }}

{% endtest %}