with
mart as (
    select sum(sum_order_amount) as sales_amount from {{ ref("mart_daily_sales") }}
),

fact as (select sum(order_amount) as sales_amount from {{ ref("fact_orders") }})

select
    mart.sales_amount as mart_sales_amount,
    fact.sales_amount as fact_sales_amount
from mart
cross join fact
where mart.sales_amount is distinct from fact.sales_amount
