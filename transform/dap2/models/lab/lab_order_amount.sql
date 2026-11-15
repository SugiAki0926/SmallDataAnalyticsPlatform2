{{ config(materialized="view", schema="lab") }}

with
orders as (
    select
        1 as order_id,
        2 as quantity,
        120 as unit_price
    union all
    select
        2 as order_id,
        1 as quantity,
        80 as unit_price
    union all
    select
        3 as order_id,
        3 as quantity,
        10 as unit_price
)

select
    order_id,
    quantity,
    unit_price,
    {{ order_amount("quantity", "unit_price") }} as order_amount
from orders
