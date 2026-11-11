select
    order_date,
    count(*) as cnt_orders,
    sum(quantity) as sum_quantity,
    sum(order_amount) as sum_order_amount,
    avg(order_amount) as avg_order_amount
from {{ ref("fact_orders") }}
group by order_date
