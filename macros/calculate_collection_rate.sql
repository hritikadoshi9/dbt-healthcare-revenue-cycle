{#
    Calculates collection rate as a percentage.
    Returns 0 if denominator is zero to avoid division errors.

    Usage:
        {{ calculate_collection_rate('paid_amount', 'billed_amount') }}
#}

{% macro calculate_collection_rate(paid_column, billed_column, precision=2) %}
    case
        when {{ billed_column }} > 0
        then round({{ paid_column }}::numeric / {{ billed_column }} * 100, {{ precision }})
        else 0
    end
{% endmacro %}
