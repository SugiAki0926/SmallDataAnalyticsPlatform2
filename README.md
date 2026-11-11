# SmallDataAnalyticsPlatform2

架空のECデータをもとにdbtの機能を学習するためのリポジトリです。架空のECデータとはいえ、任意の間隔で注文が発生させることができます。
dbtでlake、staging、fact、martまでの一連の処理が学べ、加えてsnapshot、test、seed、macro、contract、docsを扱える壊して学ぶdbt学習用リポジトリです。
codegen、dbt_utils、dbt_expectations、dbt-osmosis、pre-commitによるsqlfmt処理なども扱えるようにしています。

## 環境について

| パス                   | 役割                    |
| -------------------- | --------------------- |
| `.env`               | 接続情報などの環境変数           |
| `docker-compose.yml` | Postgresと注文ジェネレーターの管理 |
| `postgres/init`      | 初回起動時の `lake` 作成      |
| `generator`          | 注文追加と価格更新             |
| `run_daily.sh`       | 注文ジェネレーターを起動する        |
| `transform/dap2`     | dbtプロジェクト             |

データベースは `dap2_warehouse` の1つです。`lake` は注文ジェネレーターとdbtが共有します。デフォルトではスキーマに `dev_`が接頭辞につき、環境分離されています。

| 層        | schema          | 中身                    |
| -------- | --------------- | --------------------- |
| ソース      | `lake`          | ジェネレーターが注文を追加更新するテーブル |
| staging  | `dev_staging`   | `stg_ec__*`           |
| fact     | `dev_fact`      | `fact_*`              |
| mart     | `dev_mart`      | `mart_*`              |
| snapshot | `dev_snapshots` | `snap_*`              |
| seed     | `dev_seeds`     | `*.csv`               |

`transform/dap2/models/lab` と `dev_lab` は、インクリメント戦略を比べる検証用です。

## データ生成

1回の実行で注文を追加し、現在価格を1商品更新します。件数は `.env` の `ORDER_COUNT`（既定は10）です。

```bash
sh ./run_daily.sh
```

学習内容に合わせて任意に間隔を変更して登録します。

```bash
crontab -e

* * * * * /bin/sh /絶対パス/SmallDataAnalyticsPlatform2/run_daily.sh
```

## Docker コマンド関連

```bash
cp .env.example .env
docker compose -p dap2 -f docker-compose.yml up -d postgres
docker compose -p dap2 ps
docker compose -p dap2 logs postgres
docker compose -p dap2 stop postgres
docker compose -p dap2 exec postgres \
  sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "SELECT count(*) FROM lake.orders;"'
```

## dbt コマンド関連

```bash
cd /workspaces/SmallDataAnalyticsPlatform2/transform/dap2
dbt debug
dbt deps
dbt seed
dbt run
dbt run  --select fact_orders
dbt test
dbt build
dbt snapshot  --select snap_product_catalog
dbt compile  --select fact_orders
dbt test  --select test_fact_orders_amount
dbt docs generate --target dev
dbt docs serve
```
