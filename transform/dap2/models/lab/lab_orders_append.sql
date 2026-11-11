{{
    config(
        materialized="incremental",
        schema="lab",
        unique_key="order_id",
        incremental_strategy="append",
    )
}}

select order_id, sales_amount
from {{ ref("lab_order_batch") }}
{% if is_incremental() %} where order_id in (2, 3) {% endif %}
