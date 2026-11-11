{% snapshot snap_product_catalog %}

    {{
        config(
            schema="snapshots",
            unique_key="product_id",
            strategy="timestamp",
            updated_at="updated_at",
        )
    }}

    select product_id, current_price, created_at, updated_at
    from {{ source("ec", "product_catalog") }}

{% endsnapshot %}
