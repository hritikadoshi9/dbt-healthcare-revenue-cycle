{#
    Safely converts a financial column, handling nulls and rounding.
    Useful when source data may store amounts in cents.

    Usage:
        {{ safe_currency('amount_in_cents', from_cents=true) }}
        {{ safe_currency('amount_in_dollars') }}
#}

{% macro safe_currency(column_name, from_cents=false, precision=2) %}
    round(
        cast(
            coalesce({{ column_name }}, 0)
            {% if from_cents %} / 100.0 {% endif %}
            as {{ dbt.type_numeric() }}
        ),
        {{ precision }}
    )
{% endmacro %}
