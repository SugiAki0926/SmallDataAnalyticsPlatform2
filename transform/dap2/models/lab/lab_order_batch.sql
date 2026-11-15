{{ config(materialized="view", schema="lab") }}

{% if var("lab_batch", 1) | int == 1 %}
    select
        1 as order_id,
        100 as sales_amount
    union all
    select
        2 as order_id,
        200 as sales_amount
{% else %}
    select 1 as order_id, 100 as sales_amount
    union all
    select 2 as order_id, 250 as sales_amount
    union all
    select 3 as order_id, 300 as sales_amount
{% endif %}
