select
    products.product_id,
    products.product_name,
    products.category_id,
    categories.category_name,
    count(orders.order_id) as cnt_orders,
    coalesce(sum(orders.quantity), 0) as sum_quantity,
    coalesce(sum(orders.order_amount), 0) as sum_order_amount,
    sum(orders.order_amount) / nullif(count(orders.order_id), 0) as avg_order_amount
from {{ ref("stg_ec__products") }} as products
left join {{ ref("fact_orders") }} as orders on products.product_id = orders.product_id
left join
    {{ ref("stg_ec__categories") }} as categories
    on products.category_id = categories.category_id
group by
    products.product_id,
    products.product_name,
    products.category_id,
    categories.category_name
