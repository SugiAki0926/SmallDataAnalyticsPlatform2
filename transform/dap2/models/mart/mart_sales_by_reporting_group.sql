select
    reporting_groups.reporting_group,
    count(orders.order_id) as cnt_orders,
    coalesce(sum(orders.order_amount), 0) as sum_order_amount
from {{ ref("fact_orders") }} as orders
left join
    {{ ref("category_reporting_groups") }} as reporting_groups
    on orders.category_id = reporting_groups.category_id
group by reporting_groups.reporting_group
