{{
    config(
        materialized="incremental",
        unique_key="order_id",
        incremental_strategy="delete+insert",
    )
}}

with
    orders as (select * from {{ ref("stg_ec__orders") }}),
    products as (select * from {{ ref("stg_ec__products") }}),
    customers as (select * from {{ ref("stg_ec__customers") }}),
    categories as (select * from {{ ref("stg_ec__categories") }})

select
    orders.order_id,
    orders.customer_id,
    customers.customer_name,
    orders.product_id,
    products.product_name,
    products.category_id,
    categories.category_name,
    orders.quantity,
    orders.unit_price,
    {{ order_amount("orders.quantity", "orders.unit_price") }} as order_amount,
    orders.ordered_at,
    orders.order_date
from orders
left join products on orders.product_id = products.product_id
left join customers on orders.customer_id = customers.customer_id
left join categories on products.category_id = categories.category_id
{% if is_incremental() %}
    where orders.order_id > (select coalesce(max(order_id), 0) from {{ this }})
{% endif %}
