# manifest.jsonによる差分テスト・差分ビルドを学ぶ

## 目的

`manifest.json` を利用して、変更されたモデルと、その変更の影響を受ける下流モデルだけをビルド・テストする方法を学ぶ。
本来、この仕組みはCI/CDなどで活用されるが、DataAnaysisPlatform2では、GitHubのPRやブランチからのmainへのマージを行っていないので、手動で実行する。ここで学習する内容は次の5つ。

- manifest.json に何が保存されるのか
- state:modified がどのように変更を検出するのか
- Slim CIとは何か、ローカル演習と何が違うのか
- devで差分テストし、prodへ差分デプロイする方法
- SQL・設定・マクロ・データの変更が、差分検出にどう影響するのか

## Slim CIとは何か
### CIとSlim CI

dbtのように多数のモデルを扱う場合、すべてを実行すると時間や計算コストが大きくなる。そこで使われるのが Slim CI。
Slim CIは、前回の本番状態と今回の状態を比較し、変更されたモデルとその下流だけを選択してテストする仕組みである。
例えば、モデルが100個あっても、あるMartのSQLしか変更していなければ、原則としてそのMartと関連テストに実行範囲を絞ることができる。

dbt でのコマンド例は次のとおり。

```
dbt build \
  --select "state:modified+" \
  --defer \
  --state path/to/prod/artifacts
```

ここには`State selection`、`Defer`という2つの独立した仕組みがある。`state:modified+` によって変更モデルと下流モデルを選択し、`--defer` によって、選択されなかった上流モデルを開発環境でビルドせず、保存済みmanifestが指す既存のオブジェクトを利用できるようにする。この2つを組み合わせることで、Slim CIが実現される。

ここでは、差分検出・テスト・デプロイの学習が主な目的なので実際のSlimCIではない。ここではSlim CIの中核である差分検出・差分テストをdevで再現し、そのあとprodへの差分ビルドまで体験すること。

### `defer`...?

`defer`をまず理解する。次の依存関係があったとする。

```text
stg_ec__orders
       │
       ▼
  fact_orders
       │
       ▼
mart_daily_sales  ← SQLを変更
```

今回の学習では `mart_daily_sales` だけを変更する。

```text
dev_mart.mart_daily_sales
          │
          ▼
  dev_fact.fact_orders
```

変更されたMartはdevに作られる。未選択の `fact_orders` は、既に存在するdevのテーブルを参照する。
Slim CIでは、

```text
CI専用スキーマ
mart_daily_sales
        │
        ▼
prod_fact.fact_orders
```

CI専用スキーマに未変更の上流テーブルが存在しなければ、`--defer` によってprodの `fact_orders` を参照できる。これにより、すべての上流モデルを作り直さなくても、変更したMartを本番データで検証できる。ただし、`--defer` は常にprodを優先するわけではなく、未選択の上流モデルが実行先環境に存在する場合、通常はそのオブジェクトを利用する。本番側のオブジェクトを優先したい場合は、`--favor-state` を併用する。

### `manifest.json`...?

`manifest.json` は、dbtプロジェクトを解析した結果を保存するJSONファイルである。モデルのSQLだけでなく、モデル同士の依存関係、設定、マクロ、テスト、exposureなどの情報が含まれている。dbtは通常、プロジェクトを解析するコマンドを実行すると、次のファイルを生成・更新する。

```text
transform/dap2/
├── dbt_project.yml
├── models/
├── macros/
├── target/
│   └── manifest.json
└── state/
    └── prod/
        └── manifest.json
```

`target/manifest.json` は現在のプロジェクトを解析した結果で、コマンド実行によって更新される。`state/prod/manifest.json` は、比較基準として手動保存したファイル。これらを比較することで変更を検出する。

実際の`manifest.json` は、ファイルはかなり大きなJSONであり、主なトップレベルキーは次のようになっている。

```text
{
  "metadata": {},  --dbtのバージョン、manifestのスキーマバージョンなど
  "nodes": {},     --モデル、データテスト、seed、snapshotなど
  "sources": {},   --source定義
  "macros": {},    --マクロの定義
  "exposures": {}, --モデルを利用するレポートなどの定義
  "parent_map": {},--各ノードが直接依存する上流ノード
  "child_map": {}  --各ノードを直接参照する下流ノード
}
```

例えば `fact_orders`はこうなっている。`nodes` の中には、各モデルが `unique_id` をキーとして保存される。あくあｍでもこれは一部である。

```json
// $ cd transform/dap2/
// $jq '
//   .nodes
//   | to_entries[]
//   | select(.value.resource_type == "model")
//   | select(.value.name == "fact_orders")
//   | .value
//   | {
//       unique_id,
//       raw_code,
//       schema,
//       config,
//       depends_on
//     }
// ' target/manifest.json
// 上記のように書けば好きな部分をとれる。ここではベタ貼りしている
"model.dap2.fact_orders": {
      "database": "dap2_warehouse",
      "schema": "dev_fact",
      "name": "fact_orders",
      "resource_type": "model",
      "package_name": "dap2",
      "path": "fact/fact_orders.sql",
      "original_file_path": "models/fact/fact_orders.sql",
      "unique_id": "model.dap2.fact_orders",
      "fqn": [
        "dap2",
        "fact",
        "fact_orders"
      ],
      "alias": "fact_orders",
      "checksum": {
        "name": "sha256",
        "checksum": "f03d35eb39f1061637596ea613aae16f014be7f57e697ca23b0e27a7c47532e5"
      },
      "config": {
        "enabled": true,
        "alias": null,
        "schema": "fact",
        "database": null,
        "tags": [],
        "meta": {

        },
        "group": null,
        "static_analysis": null,
        "materialized": "incremental",
        "incremental_strategy": "delete+insert",
        "batch_size": null,
        "lookback": 1,
        "begin": null,
        "persist_docs": {

        },
        "post-hook": [],
        "pre-hook": [],
        "quoting": {

        },
        "column_types": {

        },
        "full_refresh": null,
        "unique_key": "order_id",
        "on_schema_change": "ignore",
        "on_configuration_change": "apply",
        "grants": {

        },
        "packages": [],
        "docs": {
          "show": true,
          "node_color": null
        },
        "contract": {
          "enforced": false,
          "alias_types": true
        },
        "event_time": null,
        "concurrent_batches": null,
        "access": "protected",
        "freshness": null,
        "on_error": null,
        "latest_version_pointer": {
          "enabled": null,
          "alias": null
        },
        "dbt-osmosis": "{model}.yml"
      },
      "tags": [],
      "description": "注文1行のファクト。注文金額は quantity * unit_price。\n増分は新しい order_id だけを取り込む。\n",
      "columns": {
        "order_id": {
          "name": "order_id",
          "description": "注文の識別子。1注文1行。",
          "meta": {

          },
          "data_type": null,
          "constraints": [],
          "quote": null,
          "config": {
            "meta": {

            },
            "tags": []
          },
          "tags": [],
          "granularity": null,
          "dimension": null,
          "entity": null,
          "doc_blocks": []
        },
        "order_amount": {
          "name": "order_amount",
          "description": "その注文の売上。quantity * unit_price。カタログの現在価格は使わない。",
          "meta": {

          },
          "data_type": null,
          "constraints": [],
          "quote": null,
          "config": {
            "meta": {

            },
            "tags": []
          },
          "tags": [],
          "granularity": null,
          "dimension": null,
          "entity": null,
          "doc_blocks": []
        }
      },
      "meta": {

      },
      "group": null,
      "docs": {
        "show": true,
        "node_color": null
      },
      "patch_path": "dap2://models/fact/fact_orders.yml",
      "build_path": null,
      "unrendered_config": {
        "schema": "fact",
        "materialized": "incremental",
        "dbt-osmosis": "{model}.yml",
        "unique_key": "order_id",
        "incremental_strategy": "delete+insert"
      },
      "created_at": 1794403325.46331,
      "relation_name": "\"dap2_warehouse\".\"dev_fact\".\"fact_orders\"",
      "raw_code": "{{\n    config(\n        materialized=\"incremental\",\n        unique_key=\"order_id\",\n        incremental_strategy=\"delete+insert\",\n    )\n}}\n\nwith\n    orders as (select * from {{ ref(\"stg_ec__orders\") }}),\n    products as (select * from {{ ref(\"stg_ec__products\") }}),\n    customers as (select * from {{ ref(\"stg_ec__customers\") }}),\n    categories as (select * from {{ ref(\"stg_ec__categories\") }})\n\nselect\n    orders.order_id,\n    orders.customer_id,\n    customers.customer_name,\n    orders.product_id,\n    products.product_name,\n    products.category_id,\n    categories.category_name,\n    orders.quantity,\n    orders.unit_price,\n    {{ order_amount(\"orders.quantity\", \"orders.unit_price\") }} as order_amount,\n    orders.ordered_at,\n    orders.order_date\nfrom orders\nleft join products on orders.product_id = products.product_id\nleft join customers on orders.customer_id = customers.customer_id\nleft join categories on products.category_id = categories.category_id\n{% if is_incremental() %}\n    where orders.order_id \u003E (select coalesce(max(order_id), 0) from {{ this }})\n{% endif %}",
      "doc_blocks": [],
      "language": "sql",
      "refs": [
        {
          "name": "stg_ec__orders",
          "package": null,
          "version": null
        },
        {
          "name": "stg_ec__products",
          "package": null,
          "version": null
        },
        {
          "name": "stg_ec__customers",
          "package": null,
          "version": null
        },
        {
          "name": "stg_ec__categories",
          "package": null,
          "version": null
        }
      ],
      "sources": [],
      "metrics": [],
      "functions": [],
      "depends_on": {
        "macros": [
          "macro.dap2.order_amount",
          "macro.dbt.is_incremental"
        ],
        "nodes": [
          "model.dap2.stg_ec__orders",
          "model.dap2.stg_ec__products",
          "model.dap2.stg_ec__customers",
          "model.dap2.stg_ec__categories"
        ]
      },
      "compiled_path": null,
      "contract": {
        "enforced": false,
        "alias_types": true,
        "checksum": null
      },
      "access": "protected",
      "constraints": [],
      "version": null,
      "latest_version": null,
      "deprecation_date": null,
      "primary_key": [],
      "time_spine": null
    }
```

ここで重要なのは、dbtがSQLファイルだけではなく、モデルの設定や依存関係まで把握していること。`raw_code` には、Jinjaを含むモデルの元のSQLが記録され、`config` にはmaterializationなどの設定が記録される。`depends_on.nodes` にはモデルやsourceへの依存関係が、`depends_on.macros` にはマクロへの依存関係が記録される。

`child_map`には直接の子ノードを記録する。依存関係がさらに多段になっていれば、dbtはグラフをたどって下流を選択できる。`state:modified+`はこれを利用して辿っていく。

```text
$jq '
  .child_map["model.dap2.fact_orders"]
' target/manifest.json

"model.dap2.fact_orders": [
      "model.dap2.mart_customer_sales",
      "model.dap2.mart_daily_sales",
      "model.dap2.mart_order_price_comparison",
      "model.dap2.mart_product_sales",
      "model.dap2.mart_sales_by_reporting_group",
      "test.dap2.assert_mart_daily_sales_amount",
      "unit_test.dap2.fact_orders.test_fact_orders_amount"
    ],
```

dbtの `state:modified` はこれらの変更や新規ノードなどをまとめて検出する。

| 変更内容          | 検出用セレクター                                | 例                        |
| ------------- | --------------------------------------- | ------------------------ |
| SQL本文の変更      | `state:modified.body`                   | `* 1` を追加                |
| モデル設定の変更      | `state:modified.configs`                | `materialized` を変更       |
| relation定義の変更 | `state:modified.relation`               | schemaやaliasを変更          |
| 利用マクロの変更      | `state:modified.macros`                 | `order_amount` の処理を変更    |
| 契約の変更         | `state:modified.contract`               | 列名やデータ型の契約を変更            |
| 永続化する説明の変更    | `state:modified.persisted_descriptions` | `persist_docs` が有効な説明を変更 |
| 新規ノード         | `state:new`                             | 新しいMartを追加               |

変更検出の対象ではないものもある。たとえば下記のようなものは対象外。

- PostgreSQLの実際のレコード内容
- lake.orders に追加された注文
- テーブルの現在の行数
- テーブルの集計値
- 前回実行時に何行insertしたか
- 前回のビルドが成功したかどうか

変更前後のSQLを直接比較してみる。

```
$ dbt build --target dev
$ dbt build --target prod
$ mkdir -p state/prod
$ cp target/manifest.json state/prod/manifest.json
```

変更前になかった`customers.customer_name`を追加して `build` したとする。

```
$ dbt build --target dev
```

変更前、変更後の `raw_code` を取得して差分を比較すると、`customers.customer_name`を追加されたことが検知できる。

```
$ jq -r '
  .nodes["model.dap2.fact_orders"].raw_code
' state/prod/manifest.json > /tmp/fact_before.sql


$ jq -r '
  .nodes["model.dap2.fact_orders"].raw_code
' target/manifest.json > /tmp/fact_after.sql

$ diff -u \
>   /tmp/fact_before.sql \
>   /tmp/fact_after.sql
--- /tmp/fact_before.sql	2026-11-14 00:41:21
+++ /tmp/fact_after.sql	2026-11-14 00:41:50
@@ -15,6 +15,7 @@
 select
     orders.order_id,
     orders.customer_id,
+    customers.customer_name,
     orders.product_id,
     products.product_name,
     products.category_id,
```

この `diff` は学習用の可視化なので、あくまでもイメージ。

## ローカル差分ビルドの実践

とりあえず理解を深めるために動かしてみる。そのための壊して学ぶデータ基盤でもある。

### STEP 1：変更前の状態を準備する

まず、devとprodを通常どおりビルドする。

```
$ dbt build --target dev
$ dbt build --target prod
```

どちらも成功したことを確認したので、ここの時点では同じ状態である。続いてprod用のmanifestを保存する。とはいえ、ここでは同じ状態のdevとprodのmanifestをprod用として保存する。

```
$ mkdir -p state/prod
$ cp target/manifest.json \
     state/prod/manifest.json
```
これが最初の比較基準になる。以降、devで実行するたびに `target/manifest.json` が更新されても、`state/prod/manifest.json` は自動では変更されない。

### STEP 2：fact_ordersのSQLを変更する

`models/fact/fact_orders.sql` を編集する。金額計算の式を次のように変更する。`* 1`は値を変えないため、既存の金額計算の意味を保ちながら、SQL本文の変更を検出する演習に使える。壊して学ぶデータ基盤なので、安全な方法を取る必要もないが。

```SQL
{{ order_amount("orders.quantity","orders.unit_price") }} * 1 as order_amount,
```

ただ、`fact_orders` は`incremental`モデルなので、通常のビルドでは既存行をすべて再計算するわけではない。

### STEP 3：変更モデルだけを確認する



前回保存したprodのmanifestと現在のdevのモデル定義を比較する。

|オプション|意味|
|:---:|:---:|
|`dbt ls`	|対象となるdbtリソースを一覧表示|
|`--target dev`|	dev環境の設定で現在のプロジェクトを解析|
|`--resource-type model`|	モデルだけを表示|
|`--select "state:modified"`|	以前の定義から変更されたモデルを選択|
|`--state ./state/prod`|	比較基準として保存済みのprod manifestを使用|

比較した結果、 `fact_orders` というモデルが変更されていると判定される。

```
$ dbt ls \
    --target dev \
    --resource-type model \
    --select "state:modified" \
    --state ./state/prod

15:52:28  Running with dbt=1.12.6
15:52:28  Registered adapter: postgres=1.11.0
15:52:29  [WARNING]: Configuration paths exist in your dbt_project.yml file which do not apply to any resources.
There are 1 unused configuration paths:
- models.dap2.dim
15:52:29  Found 16 models, 1 snapshot, 24 data tests, 1 seed, 5 sources, 1 exposure, 986 macros, 2 unit tests
dap2.fact.fact_orders
```

つまり、想定される変更モデルは次の1つである。

```text
fact_orders
```

今度は下流を含めてみると、

```
$ dbt ls \
    --target dev \
    --resource-type model \
    --select "state:modified+" \
    --state ./state/prod

15:53:54  Running with dbt=1.12.6
15:53:54  Registered adapter: postgres=1.11.0
15:53:54  [WARNING]: Configuration paths exist in your dbt_project.yml file which do not apply to any resources.
There are 1 unused configuration paths:
- models.dap2.dim
15:53:55  Found 16 models, 1 snapshot, 24 data tests, 1 seed, 5 sources, 1 exposure, 986 macros, 2 unit tests
dap2.fact.fact_orders
dap2.mart.mart_customer_sales
dap2.mart.mart_daily_sales
dap2.mart.mart_order_price_comparison
dap2.mart.mart_product_sales
dap2.mart.mart_sales_by_reporting_group
```

想定されるモデルは次の6つであることがわかる

```text
fact_orders
mart_daily_sales
mart_product_sales
mart_customer_sales
mart_order_price_comparison
mart_sales_by_reporting_group
```

この結果から、SQLを変更したモデルは1件でも、その変更の影響を受ける下流5件も選択されることが分かる。`--resource-type model` を外すと、テストやexposureなど、モデル以外のノードも確認できる。exposureは依存関係上は選択され得るが、テーブルを作成するモデルではない。

### STEP 4：devで差分ビルド・テストする

前回のprodのmanifestと現在のdevのモデル定義を比較し、変更されたモデルと、その下流モデルをdev環境で実際にビルド・テストする。`dbt ls`ではないのでビルドが実行される。

```
$ dbt build \
    --target dev \
    --select "state:modified+" \
    --state ./state/prod

15:55:57  Running with dbt=1.12.6
15:55:57  Registered adapter: postgres=1.11.0
15:55:58  [WARNING]: Configuration paths exist in your dbt_project.yml file which do not apply to any resources.
There are 1 unused configuration paths:
- models.dap2.dim
15:55:58  Found 16 models, 1 snapshot, 24 data tests, 1 seed, 5 sources, 1 exposure, 986 macros, 2 unit tests
15:55:58
15:55:58  Concurrency: 1 threads (target='dev')
15:55:58
15:55:58  1 of 9 START unit_test fact_orders::test_fact_orders_amount .................... [RUN]
15:55:58  1 of 9 PASS fact_orders::test_fact_orders_amount ............................... [PASS in 0.16s]
15:55:58  2 of 9 START sql incremental model dev_fact.fact_orders ........................ [RUN]
15:55:58  2 of 9 OK created sql incremental model dev_fact.fact_orders ................... [INSERT 0 0 in 0.09s]
15:55:58  3 of 9 START sql table model dev_mart.mart_customer_sales ...................... [RUN]
15:55:58  3 of 9 OK created sql table model dev_mart.mart_customer_sales ................. [SELECT 30 in 0.05s]
15:55:58  4 of 9 START sql table model dev_mart.mart_daily_sales ......................... [RUN]
15:55:59  [WARNING]: Detected columns with numeric type and unspecified precision/scale, this can lead to unintended rounding: ['sum_order_amount', 'avg_order_amount']`
15:55:59  4 of 9 OK created sql table model dev_mart.mart_daily_sales .................... [INSERT 0 6 in 0.11s]
15:55:59  5 of 9 START sql table model dev_mart.mart_order_price_comparison .............. [RUN]
15:55:59  5 of 9 OK created sql table model dev_mart.mart_order_price_comparison ......... [SELECT 11000 in 0.05s]
15:55:59  6 of 9 START sql table model dev_mart.mart_product_sales ....................... [RUN]
15:55:59  6 of 9 OK created sql table model dev_mart.mart_product_sales .................. [SELECT 15 in 0.04s]
15:55:59  7 of 9 START sql table model dev_mart.mart_sales_by_reporting_group ............ [RUN]
15:55:59  7 of 9 OK created sql table model dev_mart.mart_sales_by_reporting_group ....... [SELECT 4 in 0.03s]
15:55:59  8 of 9 START test assert_mart_daily_sales_amount ............................... [RUN]
15:55:59  8 of 9 PASS assert_mart_daily_sales_amount ..................................... [PASS in 0.03s]
15:55:59  9 of 9 NO-OP exposure ec_sales_learning_report ................................. [NO-OP in 0.00s]
15:55:59
15:55:59  Finished running 1 exposure, 1 incremental model, 5 table models, 1 test, 1 unit test in 0 hours 0 minutes and 0.73 seconds (0.73s).
15:55:59
15:55:59  Completed successfully
15:55:59
15:55:59  Done. PASS=8 WARN=0 ERROR=0 SKIP=0 NO-OP=1 REUSED=0 TOTAL=9
```

失敗した場合は、ここで処理を終了し、prodへの反映は行わない。

### STEP 5：prodへ差分デプロイする

devで問題がないことを確認したら、同じ変更範囲をprodへ反映する。

```
$ dbt build \
    --target prod \
    --select "state:modified+" \
    --state ./state/prod

15:57:23  Running with dbt=1.12.6
15:57:23  Registered adapter: postgres=1.11.0
15:57:24  Unable to do partial parsing because config vars, config profile, or config target have changed
15:57:24  Unable to do partial parsing because profile has changed
15:57:25  [WARNING]: Argument debug in the yaml for macro create_tags has an invalid type.
~WARNINGはSKIP~
15:57:25  [WARNING]: Configuration paths exist in your dbt_project.yml file which do not apply to any resources.
There are 1 unused configuration paths:
- models.dap2.dim
15:57:26  Found 16 models, 1 snapshot, 24 data tests, 1 seed, 5 sources, 1 exposure, 986 macros, 2 unit tests
15:57:26
15:57:26  Concurrency: 1 threads (target='prod')
15:57:26
15:57:26  1 of 9 START unit_test fact_orders::test_fact_orders_amount .................... [RUN]
15:57:26  1 of 9 PASS fact_orders::test_fact_orders_amount ............................... [PASS in 0.17s]
15:57:26  2 of 9 START sql incremental model prod_fact.fact_orders ....................... [RUN]
15:57:26  2 of 9 OK created sql incremental model prod_fact.fact_orders .................. [INSERT 0 0 in 0.10s]
15:57:26  3 of 9 START sql table model prod_mart.mart_customer_sales ..................... [RUN]
15:57:26  3 of 9 OK created sql table model prod_mart.mart_customer_sales ................ [SELECT 30 in 0.04s]
15:57:26  4 of 9 START sql table model prod_mart.mart_daily_sales ........................ [RUN]
15:57:26  [WARNING]: Detected columns with numeric type and unspecified precision/scale, this can lead to unintended rounding: ['sum_order_amount', 'avg_order_amount']`
15:57:26  4 of 9 OK created sql table model prod_mart.mart_daily_sales ................... [INSERT 0 6 in 0.08s]
15:57:26  5 of 9 START sql table model prod_mart.mart_order_price_comparison ............. [RUN]
15:57:26  5 of 9 OK created sql table model prod_mart.mart_order_price_comparison ........ [SELECT 11000 in 0.07s]
15:57:26  6 of 9 START sql table model prod_mart.mart_product_sales ...................... [RUN]
15:57:26  6 of 9 OK created sql table model prod_mart.mart_product_sales ................. [SELECT 15 in 0.03s]
15:57:26  7 of 9 START sql table model prod_mart.mart_sales_by_reporting_group ........... [RUN]
15:57:26  7 of 9 OK created sql table model prod_mart.mart_sales_by_reporting_group ...... [SELECT 4 in 0.03s]
15:57:26  8 of 9 START test assert_mart_daily_sales_amount ............................... [RUN]
15:57:26  8 of 9 PASS assert_mart_daily_sales_amount ..................................... [PASS in 0.04s]
15:57:26  9 of 9 NO-OP exposure ec_sales_learning_report ................................. [NO-OP in 0.00s]
15:57:26
15:57:26  Finished running 1 exposure, 1 incremental model, 5 table models, 1 test, 1 unit test in 0 hours 0 minutes and 0.79 seconds (0.79s).
15:57:27
15:57:27  Completed successfully
15:57:27
15:57:27  Done. PASS=8 WARN=0 ERROR=0 SKIP=0 NO-OP=1 REUSED=0 TOTAL=9
```

成功した場合だけ、保存しているmanifestを更新する。

```
$ cp target/manifest.json \
     state/prod/manifest.json
```

これにより、次回の変更検出では新しいモデル定義が基準になる。ただし、prodのビルドが途中で失敗した場合、既に実行されたモデルの更新が残っている可能性がある。manifestを更新しなければ自動的にデータベースがロールバックされるわけではないので注意。

### STEP 6：差分がなくなったことを確認する

最後に、差分がなくなったことを確認する。

```
$ dbt ls \
    --target dev \
    --resource-type model \
    --select "state:modified+" \
    --state ./state/prod

15:59:26  Running with dbt=1.12.6
15:59:26  Registered adapter: postgres=1.11.0
15:59:26  Unable to do partial parsing because config vars, config profile, or config target have changed
15:59:26  Unable to do partial parsing because profile has changed
15:59:28  [WARNING]: Argument debug in the yaml for macro create_tags has an invalid type.
~WARNINGはSKIP~
15:59:28  [WARNING]: Configuration paths exist in your dbt_project.yml file which do not apply to any resources.
There are 1 unused configuration paths:
- models.dap2.dim
15:59:28  Found 16 models, 1 snapshot, 24 data tests, 1 seed, 5 sources, 1 exposure, 986 macros, 2 unit tests
15:59:28  [WARNING]: The selection criterion 'state:modified+' does not match any enabled nodes
15:59:28  [WARNING]: No nodes selected!
```

新しい変更がなければ、選択されるモデルは0件になる。同様に、prodでも確認する。

```
$ dbt ls \
    --target prod \
    --resource-type model \
    --select "state:modified+" \
    --state ./state/prod

15:59:06  Running with dbt=1.12.6
15:59:06  Registered adapter: postgres=1.11.0
15:59:06  [WARNING]: Configuration paths exist in your dbt_project.yml file which do not apply to any resources.
There are 1 unused configuration paths:
- models.dap2.dim
15:59:07  Found 16 models, 1 snapshot, 24 data tests, 1 seed, 5 sources, 1 exposure, 986 macros, 2 unit tests
15:59:07  [WARNING]: The selection criterion 'state:modified+' does not match any enabled nodes
15:59:07  [WARNING]: No nodes selected!
```

環境依存の定義差がなければ、こちらも0件になる。

## 参考資料

- [Best practices for workflows](https://docs.getdbt.com/best-practices/best-practice-workflows?)
- [Get started with Continuous Integration tests](https://docs.getdbt.com/guides/set-up-ci?step=2&)
- [Defer](https://docs.getdbt.com/reference/node-selection/defer)
- [Continuous integration in dbt](https://docs.getdbt.com/docs/deploy/continuous-integration)
