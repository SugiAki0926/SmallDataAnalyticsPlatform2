with source as (

    select * from {{ source('ec', 'customers') }}

),

renamed as (

    select
        id as customer_id,
        name as customer_name,
        country as customer_country,
        created_at,
        updated_at

    from source

)

select * from renamed
