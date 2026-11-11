with source as (

    select * from {{ source('ec', 'product_catalog') }}

),

renamed as (

    select
        product_id,
        current_price,
        created_at,
        updated_at

    from source

)

select * from renamed
