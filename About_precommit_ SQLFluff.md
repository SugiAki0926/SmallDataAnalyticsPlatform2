# precommitで品質を高める

## 目的

ここでは、dbtのSQLをSQLFluffで検査し、その検査をGitのコミット直前に実行するprecommitを学ぶ。このリポジトリではDevContainer作成時に入れ利用にしている。

```
# sqlfluff --version
sqlfluff, version 4.5.0

# pre-commit --version
pre-commit 4.7.0

# pip show sqlfluff-templater-dbt
Name: sqlfluff-templater-dbt
Version: 4.5.0
```

`sqlfluff-templater-dbt`はsqlfluffがdbtのJinjaテンプレートを正しく解析するためのプラグイン。

### SQLFluff

SQLFluffは、SQLのLinter/Formatterで、SQLの品質を高めてくれる。まずは設定ファイル`.sqlfluff`を作成する。`[sqlfluff]、[sqlfluff:templater:dbt]`ブロックには、データベース、テンプレート、dbtなどの設定を書く。

```
[sqlfluff]
dialect = postgres --使用するデータベース
templater = dbt    -- Jinjaテンプレート`{{ref()}}, {{source()}}, {{% %}}`など正しく解析
encoding = utf-8
max_line_length = 120
runaway_limit = 10

[sqlfluff:templater:dbt]
project_dir = transform/dap2　         -- dbtプロジェクトのディレクトリ
profiles_dir = transform/dap2/profile　-- dbtプロファイルのディレクトリ
profile = dap2
target = dev

[sqlfluff:indentation]
tab_space_size = 4          -- 字下げはスペース4つ。CTE名の列は既定のまま、withと同じ列から書く

[sqlfluff:layout:type:comma]
spacing_before = touch      -- カンマの前に空白を置かない。a , ではなく a,
line_position = trailing    -- カンマは行末に置く。行頭カンマにはしない

[sqlfluff:rules:capitalisation.keywords]
capitalisation_policy = lower  -- select、from、where などのキーワードは小文字

[sqlfluff:rules:capitalisation.identifiers]
extended_capitalisation_policy = lower  -- 列名とテーブル名も小文字

[sqlfluff:rules:capitalisation.functions]
capitalisation_policy = lower  -- count、sum、coalesce などの関数名は小文字

[sqlfluff:rules:capitalisation.literals]
capitalisation_policy = lower  -- null、true、false などのリテラルは小文字

[sqlfluff:rules:aliasing.table]
aliasing = explicit         -- テーブルの別名には as を付ける

[sqlfluff:rules:aliasing.column]
aliasing = explicit         -- 列の別名にも as を付ける
```

すべてのSQLファイルを対象にする必要はないので、`.sqlfluffignore`に対象外にするファイルを記載する。

```
transform/dap2/target/
transform/dap2/dbt_packages/
transform/dap2/macros/
```

下記のコマンドで、`models`ファイル全体を検査できる。ルールから逸脱している場合、ルールと行番号を教えてくれる。

```
# sqlfluff lint models/
```

モデルを絞ることもできる。意図的に`fact_orders.sql`をルールから逸脱するように書き換えて実行すると、逸脱がわんさか出てくる。

```
# sqlfluff lint models/fact/fact_orders.sql
=== [dbt templater] Sorting Nodes...
=== [dbt templater] Compiling dbt project...
=== [dbt templater] Project Compiled.
== [models/fact/fact_orders.sql] FAIL
L:   9 | P:   1 | LT02 | Line should not be indented. [layout.indent]
L:  10 | P:   1 | LT02 | Line should not be indented. [layout.indent]
L:  10 | P:   5 | LT08 | Blank line expected but not found after CTE closing
                       | bracket. [layout.cte_newline]
L:  11 | P:   1 | LT02 | Line should not be indented. [layout.indent]
L:  11 | P:   5 | LT08 | Blank line expected but not found after CTE closing
                       | bracket. [layout.cte_newline]
L:  12 | P:   1 | LT02 | Line should not be indented. [layout.indent]
L:  12 | P:   5 | LT08 | Blank line expected but not found after CTE closing
                       | bracket. [layout.cte_newline]
All Finished 📜 🎉!
```

`fix`コマンドで自動で修正できる。`fix`コマンドですべてのルールに沿うように修正されるわけでもいないが、今回は`lint`コマンドでも問題点は指摘されない。

```
2# sqlfluff fix models/fact/fact_orders.sql
==== finding fixable violations ====
=== [dbt templater] Sorting Nodes...
=== [dbt templater] Compiling dbt project...
=== [dbt templater] Project Compiled.
== [models/fact/fact_orders.sql] FAIL
L:   9 | P:   1 | LT02 | Line should not be indented. [layout.indent]
L:  10 | P:   1 | LT02 | Line should not be indented. [layout.indent]
L:  10 | P:   5 | LT08 | Blank line expected but not found after CTE closing
                       | bracket. [layout.cte_newline]
L:  11 | P:   1 | LT02 | Line should not be indented. [layout.indent]
L:  11 | P:   5 | LT08 | Blank line expected but not found after CTE closing
                       | bracket. [layout.cte_newline]
L:  12 | P:   1 | LT02 | Line should not be indented. [layout.indent]
L:  12 | P:   5 | LT08 | Blank line expected but not found after CTE closing
                       | bracket. [layout.cte_newline]
== [models/fact/fact_orders.sql] FIXED
7 fixable linting violations found

# sqlfluff lint models/fact/fact_orders.sql
=== [dbt templater] Sorting Nodes...
=== [dbt templater] Compiling dbt project...
=== [dbt templater] Project Compiled.
All Finished 📜 🎉!
```


## precommit

precommitはそもそsqlfluffとは直接的に関係はない。gitのコミット時に自動で動かす仕組みのこと。commitは開発で必ず実行するので、そのときにlinter/formmaterを実行すれば品質を担保しやすい。

まずは設定ファイルをリポジトリのルートに `.pre-commit-config.yaml` を作り、次の内容にする。

```yaml
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v6.0.0 # 汎用フックの版
    hooks:
      - id: check-yaml             # YAMLの構文を検査する
      - id: end-of-file-fixer      # ファイル末尾を改行1つにする
      - id: trailing-whitespace    # 行末の空白を削除する
      - id: requirements-txt-fixer # requirements.txtの並びを整える
  - repo: https://github.com/sqlfluff/sqlfluff
    rev: 4.5.0 # SQLfluffのバージョン
    hooks:
      - id: sqlfluff-lint # 検査だけ行う。SQLは書き換えない
        name: SQLFluff lint               # コミット時に表示する名前
        files: ^transform/dap2/(models|snapshots|tests)/.*\.sql$ # models・snapshots・testsだけを渡す
        additional_dependencies:          # フック専用の環境へ追加するパッケージ
          - sqlfluff-templater-dbt==4.5.0 # dbtのrefとマクロを展開する
          - dbt-core==1.12.6              # イメージと同じdbt本体
          - dbt-postgres==1.11.0          # Postgres用のdbtアダプタ
  - repo: https://github.com/astral-sh/ruff-pre-commit
    rev: v0.14.10 # Ruffの版
    hooks:
      - id: ruff-check # Pythonの違反を検査する
        args: [--fix, --exit-non-zero-on-fix] # 自動修正したらコミットを一度止める
      - id: ruff-format # Pythonの見た目を整形する
```

`pre-commit run`でprecommitが動くかどうか確認しておく。

```
# pre-commit run --all-files
SQLFluff lint............................................................Passed
check yaml...............................................................Passed
fix end of files.........................................................Passed
trim trailing whitespace.................................................Passed
fix requirements.txt.....................................................Passed
ruff check...............................................................Passed
ruff format..............................................................Passed
```

問題なく動いていることがわかる。これで`git commit`の際に
