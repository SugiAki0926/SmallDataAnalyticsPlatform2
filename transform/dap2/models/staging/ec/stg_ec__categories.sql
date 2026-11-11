with source as (

    select * from {{ source('ec', 'categories') }}

),

renamed as (

    select
        id as category_id,
        name as category_name,
        created_at,
        updated_at

    from source

)

select * from renamed
