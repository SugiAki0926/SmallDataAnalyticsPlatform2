select categories.category_id, categories.category_name
from {{ ref("stg_ec__categories") }} as categories
left join
    {{ ref("category_reporting_groups") }} as groups
    on categories.category_id = groups.category_id
where groups.category_id is null
