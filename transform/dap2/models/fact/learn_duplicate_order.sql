{{ config(enabled=false) }}

-- 意図的に order_id を重複させ、unique テストを失敗させる学習用モデル。
-- enabled=false のため、dbt build ではモデルもテストも実行しない。
-- {{ config(materialized="view") }}
-- select order_id
-- from {{ ref("stg_ec__orders") }}
-- where order_id = (select min(order_id) from {{ ref("stg_ec__orders") }})
-- union all
-- select order_id
-- from {{ ref("stg_ec__orders") }}
-- where order_id = (select min(order_id) from {{ ref("stg_ec__orders") }})
