select
    groups.reporting_group,
    count(orders.order_id) as cnt_orders,
    coalesce(sum(orders.order_amount), 0) as sum_order_amount
from {{ ref("fact_orders") }} as orders
left join
    {{ ref("category_reporting_groups") }} as groups
    on orders.category_id = groups.category_id
group by groups.reporting_group
