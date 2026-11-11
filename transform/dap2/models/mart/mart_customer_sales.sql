select
    customers.customer_id,
    customers.customer_name,
    customers.customer_country,
    count(orders.order_id) as cnt_orders,
    coalesce(sum(orders.quantity), 0) as sum_quantity,
    coalesce(sum(orders.order_amount), 0) as sum_order_amount,
    sum(orders.order_amount) / nullif(count(orders.order_id), 0) as avg_order_amount
from {{ ref("stg_ec__customers") }} as customers
left join
    {{ ref("fact_orders") }} as orders on customers.customer_id = orders.customer_id
group by customers.customer_id, customers.customer_name, customers.customer_country
