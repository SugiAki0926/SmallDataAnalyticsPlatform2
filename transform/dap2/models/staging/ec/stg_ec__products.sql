with source as (

    select * from {{ source('ec', 'products') }}

),

renamed as (

    select
        id as product_id,
        name as product_name,
        category_id,
        base_price,
        created_at,
        updated_at

    from source

)

select * from renamed
