{#
  dev:  dap2_warehouse.dev_staging.stg_ec__orders
  prod: dap2_warehouse.prod_staging.stg_ec__orders
  lake は dev/prod共有
#}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- set default_schema = target.schema -%}
    {%- if custom_schema_name is none -%} {{ default_schema }}
    {%- else -%} {{ default_schema }}_{{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
