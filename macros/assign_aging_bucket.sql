{#
    Assigns a claim to an AR aging bucket based on days outstanding.
    Uses configurable bucket thresholds from dbt_project.yml vars.

    Usage:
        {{ assign_aging_bucket('days_outstanding') }}
#}

{% macro assign_aging_bucket(days_column) %}
    {%- set buckets = var('aging_buckets', [30, 60, 90, 120]) -%}
    case
        {%- for i in range(buckets | length) %}
        {%- if i == 0 %}
        when {{ days_column }} <= {{ buckets[i] }}
            then '0-{{ buckets[i] }} days'
        {%- else %}
        when {{ days_column }} <= {{ buckets[i] }}
            then '{{ buckets[i-1] + 1 }}-{{ buckets[i] }} days'
        {%- endif %}
        {%- endfor %}
        else '{{ buckets[-1] + 1 }}+ days'
    end
{% endmacro %}
