select
    categories.category_id,
    categories.category_name
from {{ ref("stg_ec__categories") }} as categories
left join
    {{ ref("category_reporting_groups") }} as reporting_groups
    on categories.category_id = reporting_groups.category_id
where reporting_groups.category_id is null
