{{ config(materialized="view", schema="lab") }}

{% if var("lab_batch", 1) | int == 1 %}
    select 1 as order_id, 100 as sales_amount
    union all
    select 2, 200
{% else %}
    select 1 as order_id, 100 as sales_amount
    union all
    select 2, 250
    union all
    select 3, 300
{% endif %}
