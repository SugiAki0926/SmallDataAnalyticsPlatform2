select order_id, quantity, unit_price
from {{ ref("stg_ec__orders") }}
where 0 >= quantity or 0 > unit_price
