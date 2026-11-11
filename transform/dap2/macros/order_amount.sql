{% macro order_amount(quantity, unit_price) %}
    {{ quantity }} * {{ unit_price }}
{% endmacro %}
