# 増分の3つの反映方法

検証用スキーマは `dap2_warehouse.dev_lab`。dbt は `models/lab` の `schema='lab'` に、target の `dev` を付けて `dev_lab` を作る。

| モデル | 役割 |
| --- | --- |
| `lab_order_batch` | 入力を切り替える view |
| `lab_orders_append` | `incremental_strategy='append'` |
| `lab_orders_delete_insert` | `incremental_strategy='delete+insert'` |
| `lab_orders_merge` | `incremental_strategy='merge'` |

3つの増分モデルは、いずれも `unique_key='order_id'`。SELECT は同じで、戦略だけが違う。

```sql
select order_id, sales_amount
from {{ ref("lab_order_batch") }}
{% if is_incremental() %}
where order_id in (2, 3)
{% endif %}
```

## 1. どの行を渡すか

`lab_order_batch` は var `lab_batch` で入力を切り替える。

`lab_batch: 1`

| order_id | sales_amount |
| --- | --- |
| 1 | 100 |
| 2 | 200 |

`lab_batch: 2`

| order_id | sales_amount | 意味 |
| --- | --- | --- |
| 1 | 100 | 変更なし |
| 2 | 250 | 既存注文の訂正 |
| 3 | 300 | 新しい注文 |

`is_incremental()` は、対象の表が既にあり、`--full-refresh` でないときに true。true のときだけ `where order_id in (2, 3)` が付く。

1回目。`is_incremental()` は false。where は付かない。入力の2件がそのまま入る。

```bash
dbt run --target dev --full-refresh --select lab_order_batch+ --vars '{lab_batch: 1}'
```

2回目。`is_incremental()` は true。ソースには注文1、2、3があるが、処理へ渡るのは注文2と注文3だけ。

```bash
dbt run --target dev --select lab_order_batch+ --vars '{lab_batch: 2}'
```

WHERE は、どの行を処理に渡すか。append / delete+insert / merge は、渡された行をどう反映するか。

## 2. this

`{{ this }}` は、そのモデル自身が作る表。`lab_orders_merge` の中では `dap2_warehouse.dev_lab.lab_orders_merge` になる。append、delete+insert も、それぞれの自分の表を指す。

```sql
where order_id > (select max(order_id) from {{ this }})
```

既存の最大 `order_id` が 2 なら、この条件で渡るのは注文3だけ。訂正された注文2は抽出されない。merge を指定していても、渡されなかった注文2の売上 250 は反映されない。

`this` を参照する条件は `{% if is_incremental() %}` の中に置く。初回は表がまだ無く、max を取る相手が無い。`--full-refresh` のときも `is_incremental()` は false なので、この条件は付かない。

## 3. 渡された行の反映

初回のあと、3表とも次の2件。

| order_id | sales_amount |
| --- | --- |
| 1 | 100 |
| 2 | 200 |

2回目に渡したのは次の2件。

| order_id | sales_amount | 意味 |
| --- | --- | --- |
| 2 | 250 | 既存注文の訂正 |
| 3 | 300 | 新しい注文 |

### append

既存の注文IDと照合せず、渡された2件を追加する。`unique_key` を書いてあっても、戦略が append のときは重複を除かない。注文2が2行になる。

```sql
SELECT * FROM dap2_warehouse.dev_lab.lab_orders_append;
```

| order_id | sales_amount |
| --- | --- |
| 1 | 100 |
| 2 | 200 |
| 2 | 250 |
| 3 | 300 |

### delete+insert

1. 今回の入力にある order_id 2 と 3 を、既存表から削除する。該当したのは注文2。
2. 渡された2件を挿入する。

全件は削除しない。注文1は残る。

```sql
SELECT * FROM dap2_warehouse.dev_lab.lab_orders_delete_insert;
```

| order_id | sales_amount |
| --- | --- |
| 1 | 100 |
| 2 | 250 |
| 3 | 300 |

### merge

注文2は既にあるので、売上を 200 から 250 に更新する。注文3は無いので追加する。注文1は渡されていないので、そのまま残る。

```sql
SELECT * FROM dap2_warehouse.dev_lab.lab_orders_merge;
```

| order_id | sales_amount |
| --- | --- |
| 1 | 100 |
| 2 | 250 |
| 3 | 300 |

この入力では、delete+insert と merge の最終行は同じ。違うのは、同じ `order_id` を削除して入れ直すか、既存行を更新するか。

| 方式 | 同じIDが既にある場合 | 新しいIDの場合 |
| --- | --- | --- |
| append | そのまま追加するので重複する | 追加 |
| delete+insert | 削除して入れ直す | 追加 |
| merge | 更新 | 追加 |

## 4. fact_orders との違い

`fact_orders` の増分条件は次のとおり。

```sql
where orders.order_id > (select coalesce(max(order_id), 0) from {{ this }})
```

新しい `order_id` だけを渡す。既存注文の単価訂正や、商品名の変更は渡されない。戦略を merge に変えても、渡されなかった行は更新されない。この lab の `where order_id in (2, 3)` は、訂正行も渡すための検証用の条件。
