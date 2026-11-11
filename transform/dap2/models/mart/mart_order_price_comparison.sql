select
    orders.order_id,
    orders.product_id,
    orders.ordered_at,
    orders.quantity,
    orders.unit_price,
    orders.order_amount,
    catalog.current_price as catalog_price,
    orders.unit_price - catalog.current_price as price_difference,
    case
        when catalog.product_id is null
        then 'no price history'
        else 'price history exists'
    end as price_history_status
from {{ ref("fact_orders") }} as orders
left join
    {{ ref("snap_product_catalog") }} as catalog
    on orders.product_id = catalog.product_id
    and orders.ordered_at >= catalog.dbt_valid_from
    and (catalog.dbt_valid_to is null or orders.ordered_at < catalog.dbt_valid_to)



