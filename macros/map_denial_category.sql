{#
    Maps a CARC denial reason code to a human-readable category.
    Supports overrides via the denial_category_override variable in dbt_project.yml.

    Usage:
        {{ map_denial_category('denial_reason_code') }}
#}

{% macro map_denial_category(code_column) %}
    {%- set overrides = var('denial_category_override', {}) -%}

    case
        {%- for code, category in overrides.items() %}
        when {{ code_column }} = '{{ code }}' then '{{ category }}'
        {%- endfor %}
        when {{ code_column }} in ('1', '2', '3') then 'Patient Responsibility'
        when {{ code_column }} in ('4', '5', '181', '182', '236') then 'Coding Error'
        when {{ code_column }} in ('16', '151', '226', '227') then 'Missing Information'
        when {{ code_column }} = '18' then 'Duplicate'
        when {{ code_column }} in ('26', '27', '31', '32', '33', '109') then 'Eligibility'
        when {{ code_column }} = '29' then 'Timely Filing'
        when {{ code_column }} in ('39', '55', '136', '197') then 'Authorization'
        when {{ code_column }} in ('49', '170') then 'Medical Necessity'
        when {{ code_column }} in ('50', '96', '167', '204') then 'Non-Covered Service'
        when {{ code_column }} in ('23', '45', '97') then 'Contractual'
        when {{ code_column }} in ('35', '119', '222') then 'Benefit Limit'
        when {{ code_column }} = '234' then 'Bundling'
        when {{ code_column }} = '242' then 'Out of Network'
        else 'Uncategorized'
    end
{% endmacro %}
