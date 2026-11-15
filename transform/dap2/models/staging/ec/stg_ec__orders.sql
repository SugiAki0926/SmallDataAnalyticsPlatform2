with
source as (select * from {{ source("ec", "orders") }}),

renamed as (

    select
        id as order_id,
        customer_id,
        product_id,
        quantity,
        unit_price,
        ordered_at,
        created_at,
        updated_at,
        (ordered_at at time zone 'Asia/Tokyo')::date as order_date

    from source

)

select *
from renamed
order by ordered_at asc
