# SmallDataAnalyticsPlatform2（dap2）— ECデータ生成・dbt学習環境 仕様書・共同編集稿

更新日：2026-11-07 / 版：0.5 / 状態：要件整理中

利用者との合意を反映した仕様書。「確定」は合意済みの方針、「暫定」は細部を具体化するための案。実装コード・Mac 実機の動作は未検証。仕様への反映と実装完了を区別する。

## 1. 目的・対象環境【確定】

正式名称は **SmallDataAnalyticsPlatform2**、略称は **dap2**。既存の dap とは別プロジェクトであり、コンテナなどの作成リソースには dap2 を付け、既存 dap のリソースを共有・変更しない。

Mac 上で架空 EC データを少量ずつ生成・追加・更新し、生きているデータを使って dbt Core の加工、テスト、履歴管理を学ぶ。艇理とは別プロジェクト。

- Raspberry Pi は全て対象外。運用・開発・DB・Dev Container は Mac 上で完結する。
- 開発＝本番。同じ Compose、DB、接続ユーザーを使う。dev/prod の環境分離・スキーマ分離は設けない。
- dlt は使用しない。Mac の cron から run_daily.sh を実行し、シェルスクリプトから Python の生成処理を起動し、PostgreSQL の lake に直接 INSERT / UPDATE する。
- 実行するたびに追加・更新する。同日成功済みを理由にスキップしない。
- dbt プロジェクトの初期化、モデル、snapshot、テスト等は利用者が最初から作る。AI は dbt init やモデル作成・実行を代行しない。
- dbt 未作成でもデータ生成を開始できる。初期 snapshot 完了は生成開始の条件にしない。
- 初期スケジュールは毎朝 07:00 JST。5分間隔などへの変更は Mac の cron で行う。

## 2. レビュー事項の決定

| ID | 状態 | 方針 |
|---|---|---|
| R01 | 確定 | dlt 不使用。Python から lake に直接生成・追加・更新 |
| R02 | 確定 | run_date 主キーや予定実行枠による重複生成防止は不要。実行のたびに生成 |
| R03 | 確定 | dbt は未作成で開始し、利用者が dbt init から実装。生成と独立して学習を進める |
| R04 | 確定 | snapshot の成否で次の生成を止めない。厳密な履歴復旧制御は不要 |
| R05 | 確定 | 再実行も新しい追加・更新。FORCE_GENERATOR と実行記録削除による強制生成は不要 |
| R06 | 確定 | 開発＝本番、同じ接続ユーザー。dev/prod ごとの権限分離なし |
| R07 | 確定 | Dev Container を Mac 上で起動。Remote SSH は不要 |
| R08 | 方針確定 | 前回実行より後〜今回実行時の範囲でランダム生成。注文時刻への適用と解釈。境界・初回規則は第5節の暫定案 |
| R09 | 確定 | Mac で動作する構成を優先。具体的なバージョンの互換性は実装時に検証 |
| R10 | 整理済み | 入口名は run_daily.sh。シェルスクリプトから generator/daily.py を起動、ドキュメント生成は dbt docs generate。章番号を統一 |

## 3. 技術構成

| 用途 | 方針 |
|---|---|
| ホスト | Mac、タイムゾーン Asia/Tokyo。利用端末の CPU アーキテクチャを実装時に確認 |
| コンテナ | Mac 上の Docker Compose、プロジェクト名 dap2 |
| DB | PostgreSQL 16、DB dap2_warehouse、元データは lake |
| データ生成 | Python 3.12、generator/daily.py。cron → run_daily.sh 経由で起動する1回限りの処理 |
| DB ドライバー | 元案 psycopg2-binary==2.9.9 を候補として互換性を検証。変更する場合は理由と採用版を記録 |
| データ変換 | 元案 dbt Core 1.11.9 / dbt-postgres 1.11.0 は候補。利用者のセットアップ前に導入可能な組合せを確認 |
| 定期実行 | Mac の cron → run_daily.sh → generator コンテナ内の generator/daily.py |
| 編集 | Mac の VS Code + Dev Container dap2-dbt、dbt Power User |
| DB確認 | Mac の DBeaver Community から localhost 接続。SSH トンネルは不要 |
| 日時 | TIMESTAMPTZ、DB の timezone / log_timezone は Asia/Tokyo |

Python・dbt の依存はコンテナ側にまとめる。Mac 側の run_daily.sh が Docker Compose を呼び出し、generator コンテナ内で Python の generator/daily.py を実行する。ホスト側の Python ラッパー run_daily.py は設けない。

## 4. データフロー・Compose

定期生成：Mac cron → run_daily.sh（Mac）→ Docker Compose → generator/daily.py（コンテナ内の Python）→ dap2_warehouse.lake。
学習：利用者が Dev Container で dbt を実行 → lake を参照 → 加工結果・snapshot を保存。

初期の cron はデータ生成のみを担当する。dbt の定期実行は、利用者がモデル等を作った後に別途追加する。生成開始を dbt の準備状態に依存させない。

- リポジトリ直下：docker-compose.yml。開発用 Compose が必要なら編集コンテナの追加用とし、別環境にはしない。
- 常駐：PostgreSQL。生成ジョブ：docker compose run --rm で実行し終了後に削除。
- PostgreSQL の永続ボリューム：Compose 内のキー pgdata、Docker 上の実名 dap2_pgdata。コンテナ内 /var/lib/postgresql/data。
- ホスト公開：127.0.0.1:${POSTGRES_PORT}:5432。
- DBeaver：127.0.0.1:${POSTGRES_PORT}、DB dap2_warehouse。
- コンテナからの接続：postgres:5432。
- ネットワーク実名：dap2 を予定。Dev Container が別 Compose プロジェクトなら既存ネットワークを共有する。
- healthcheck：初期化中の一時サーバーを完了扱いしない。ジョブ開始時に対象 DB・必要テーブルへの接続を確認する。
- PID 1 の確認方法など、healthcheck の具体実装は採用イメージで検証する。

### 4.1 リソース命名・既存 dap との分離【確定】

| 対象 | 名称・規則 |
|---|---|
| 正式名称 / 略称 | SmallDataAnalyticsPlatform2 / dap2 |
| プロジェクトディレクトリ | dap2。既存 dap と別ディレクトリ |
| Compose プロジェクト名 | dap2。Compose 設定と run_daily.sh の呼び出しで統一 |
| PostgreSQL コンテナ | dap2-postgres-1 等、dap2 で始まる名前 |
| 生成ジョブコンテナ | dap2-generator-run-… 等、dap2 で始まる一時コンテナ名 |
| Dev Container | 表示名 dap2-dbt。実コンテナ名にも dap2 を含める |
| 独自ビルドイメージ | dap2-generator、dap2-dbt 等。公式ベースイメージの名称はそのまま使用 |
| ネットワーク実名 | dap2。既存 dap のネットワークに接続しない |
| 永続ボリューム実名 | dap2_pgdata。追加の名前付きボリュームも dap2_ 接頭辞 |
| DB / DBユーザー | dap2_warehouse / dap2。読み取り専用を設ける場合は dap2_reader |
| dbt プロジェクト / プロファイル | dap2 |
| ホスト側ログ | dap2 ディレクトリ内の logs/dap2-generator.log 等 |
| cron | dap2 の run_daily.sh を絶対パスで指定。既存 dap の登録を維持 |

Compose 内のサービスキー postgres / generator / dbt はプロジェクト内の識別子として使用できるが、実際に作成されるリソース名には dap2 を含める。固定の container_name を指定する場合も同じ規則とし、一時ジョブは固有の接尾辞を許容する。

lake や analytics、orders 等の DB 内名称は、dap2 専用の PostgreSQL・DB 内に閉じるため既存名称を維持する。設定ファイルやスクリプトも dap2 専用ディレクトリに置く。Dev Container の追加 Compose で別プロジェクト名が必要な場合は dap2-devcontainer 等とし、接続先は dap2 のみとする。

**ホスト公開ポートは名前だけでは分離できない。** PostgreSQL のホスト側ポートは暫定で **15432** とし、実装時に既存 dap とその他のプロセスが使用していないことを確認して確定する。コンテナ内は5432のまま。DBeaver は 127.0.0.1:15432 に接続する。競合時は dap2 側の POSTGRES_PORT を変更し、既存 dap の設定は変更しない。

run_daily.sh は dap2 の Compose ファイルとプロジェクト名を明示し、既存 dap を起動・停止・削除しない。Dev Container、手動操作、cron の全経路で同じ命名規則を適用する。

## 5. 元データ・生成規則

### 5.1 テーブル

lake 内のリレーショナルテーブルに直接書き込む。外部からのデータ転送や毎回の replace は行わない。

| テーブル | 初期行数 | 内容 | 定期変化 |
|---|---:|---|---|
| categories | 8 | 商品カテゴリ | 原則なし |
| products | 15 | 商品・カテゴリ・基準価格 | 原則なし |
| customers | 30 | 顧客・国 | 原則なし |
| orders | 50 | 1注文1商品。数量、販売単価、ordered_at | INSERT |
| product_catalog | 15 | 商品ごとの現在価格、updated_at | UPDATE |

order_items、payments は作らない。orders.id は BIGSERIAL。product_catalog.updated_at の索引は元案を継承するが、初期の小規模データでは性能上の必須条件にしない。

重複実行防止用の generator_runs は必須にしない。ランダム時刻生成に必要な前回成功時刻だけを保存する案を採用候補とする（第6節）。

### 5.2 1実行当たりの生成

| 項目 | 規則 |
|---|---|
| 入口 | generator/daily.py、1回で終了 |
| 通常注文 | 既定10件 |
| 価格更新 | 既定1商品、基準価格の±10% |
| フラッシュセール | 既定0件。指定時は現行価格の70〜85%で追加 |
| 選択の偏り | id 順で先頭15%の顧客と先頭20%の商品へ通常注文を寄せる。確率・端数処理は元コード確認後に明記 |
| 数量 | 通常注文は1〜2 |
| 販売単価 | 通常注文は現行価格の±10% |
| 順序 | 注文追加→価格更新。1回の生成を同一トランザクションで処理 |
| 同日再実行 | 通常どおり新たな注文を追加し、価格を更新 |
| 失敗 | その実行の注文・価格・前回成功時刻の変更をロールバック |
| 初期50注文 | 行ごとに顧客・商品を選ぶ。再初期化時に内容が変わることを許容 |

生成件数は実行間隔に比例して自動増減させない。5分間隔に変更すれば各回で既定10件を生成する。停止期間が長くても、再開時の1回で生成する件数は同じ。

### 5.3 注文時刻【R08】

ユーザー指定の「前回実行より後から実行時の値でランダムに生成」は、orders.ordered_at の生成範囲として扱う。価格・数量は第5.2節の規則を維持する。

具体化の暫定案：

- 前回成功した生成処理の基準時刻を t_prev とする。失敗した実行では更新しない。
- 今回の生成処理開始時に基準時刻 t_now を一度取得する。
- 各注文の ordered_at を t_prev < ordered_at <= t_now の範囲で独立に一様ランダム生成する。
- 成功時に前回成功時刻を t_now に進める。最大注文時刻を代用すると次回の範囲が曖昧になるため、別に保存する。
- 例：前回07:00、今回07:05なら、07:00より後〜07:05の間に10件をランダム配置する。
- product_catalog.updated_at は今回の価格更新時刻 t_now とする案。注文を先に作るため、注文は更新前の現行価格を参照する。
- 初期50注文は初期化時刻の直前24時間から生成し、初期化時刻を t_prev の初期値とする案。
- 時計の巻き戻り等で t_now <= t_prev になった場合は、有効な生成区間がないためエラーとし、状態を進めない案。

初回の24時間幅は未確定の暫定値。注文時刻の区間を定義する状態は、同日実行を抑止するための管理ではない。

### 5.4 データの意味・残る細部

- 注文売上は quantity × 注文に保存した販売単価。現在のカタログ価格で過去の売上を再計算しない。
- products の価格＝基準価格、product_catalog＝現在価格、orders＝販売実績単価。
- 金額は NUMERIC、単一通貨を想定。通貨・小数桁・丸め規則は未決。
- 税・送料・返品は初期版の対象外とする案。
- 価格更新対象は1実行内で重複させず、指定件数が商品数を超えたらエラーとする案。
- 価格を丸めた結果同額になった場合に updated_at を進めるかは未決。
- 「価格影響」はまず記述的な比較を学ぶ。価格に需要が反応する生成規則がない状態で、価格の因果効果を評価する教材とはしない。

元 SQL で初期注文が0件になるという説明は、該当コミットと再現結果が未確認。PostgreSQL 16 固有の不具合とは断定しない。各注文で顧客・商品を選ぶ実装と50件の生成結果を確認する。

## 6. 実行・失敗時の扱い【簡素化】

- run_date 主キー、run_key による再試行識別、同日スキップ、強制生成フラグは設けない。
- 呼び出しごとに新しいデータを追加・更新する。正常終了後に再度呼び出した場合も追加する。
- 生成トランザクションが失敗した場合はロールバックし、次の呼び出しで改めて生成する。
- コミット後の応答喪失などで成否が不明な場合も、再呼び出しで追加され得ることを許容する。
- dbt、snapshot、docs の失敗によって、その後のデータ生成を止めない。生成済みデータも巻き戻さない。
- 厳密なパイプライン進捗テーブル、未完了実行の自動復旧は作らない。
- 実行件数、開始・終了、エラー、終了コードをログに残す。

前回成功時刻の保存方法【暫定案】：

lake.generator_state に1行だけ保持する。列は id（固定値1の主キー）と last_success_at（TIMESTAMPTZ）。これは時刻の生成範囲を決める状態であり、実行の重複防止記録ではない。

生成トランザクション内でこの行をロックして読み、今回の基準時刻を取得し、注文・価格と一緒に更新する。同時起動は順番に処理し、それぞれ生成する。既に生成済みという理由でどちらかをスキップしない。Mac ホストの flock への依存は設けない。

snapshot は利用者が実行した時点の状態を履歴化する。実行の間に複数回更新した中間価格や、snapshot 開始前の価格は残らないことを許容する。全変更を完全に残すことは初期要件にしない。

## 7. dbt【利用者が初期から作成】

- プロジェクト予定位置：dbt/dap2。プロファイル名：dap2。
- dbt init、profiles.yml、source、モデル、snapshot、テストは利用者が作成する。
- AI が作る基盤に、完成済み dbt モデルや初期 snapshot 実行を含めない。
- 初期の生成ジョブは dbt コマンドを呼び出さない。
- lake は source として参照する。dbt の加工結果は lake へ書かない。
- 開発＝本番の単一 target とする。名前 local、出力スキーマ analytics を暫定案とする。dev/prod target は不要。
- 同じ POSTGRES_USER / POSTGRES_PASSWORD を使用し、環境別の接続ユーザーは作らない。
- profiles.yml をプロジェクト内へ置く場合は profiles の参照先を明示する。
- staging/intermediate/marts はまずフォルダとモデル名で区分する案。

学習対象：staging（列・型・時刻）、intermediate（結合と売上）、marts（日次・商品別・顧客別・価格比較）、注文ファクトの incremental、product_catalog の snapshot、unique/not_null/relationships/範囲チェック/unit test、documentation/seeds/macros/contracts/exposures。

snapshot の予定設定：unique_key=product_id、strategy=timestamp、updated_at=updated_at。いつ作り始めるかは利用者が決める。

利用者が dbt を定期実行へ組み込む場合は、対象モデル・snapshot・テストの実行範囲をその時点で決める。dbt docs generate も必要になった段階で追加する。

## 8. Mac の cron・セットアップ

1. Mac の Docker 環境と、run_daily.sh を実行するシェルを準備する。
2. PostgreSQL と初期データを準備する。
3. 生成処理を手動実行し、lake への追加・更新を確認する。
4. Mac の cron に run_daily.sh を登録し、実行結果をログで確認する。
5. 利用者が Mac の Dev Container で dbt init から学習を進める。cron 登録前に学習を始めてもよい。

Mac 向け実装・検証条件：

- cron ではシェルと run_daily.sh の絶対パスを指定する。run_daily.sh では Docker CLI、作業ディレクトリ、Compose ファイルの参照先を明示する。
- run_daily.sh はコンテナ内の Python 処理の終了を待ち、失敗時の非ゼロ終了コードをそのまま呼び出し元へ返す。
- 対話シェルの初期化ファイルや conda の自動有効化に依存しない。
- .env は指定したプロジェクトから読み込む。パスワードを Git やログへ出さない。
- ホストとコンテナの JST 設定を確認する。
- cron の実行時には Mac と Docker エンジン・DB が稼働していることを運用前提にする。
- スリープ・電源断・Docker 停止中の定刻実行は保証しない。自動起動・自動復旧・未実行回数の補完は初期範囲外。
- 次に実行できたときは、前回成功時刻から今回までを時刻生成の対象にする。停止期間分の注文件数を自動で増やさない。
- 標準出力・標準エラーをホスト側のログに保存する。

| 変数 | 初期値・方針 |
|---|---|
| POSTGRES_USER / POSTGRES_PASSWORD | .env.example は dap2 / change-me。生成・dbt で共通 |
| POSTGRES_READER_PASSWORD | change-me-reader。任意の読み取り専用 dap2_reader 用。環境分離とは別 |
| POSTGRES_PORT | 暫定15432。既存 dap 等との非競合を確認して確定。コンテナ内は5432 |
| ORDER_COUNT | 10。旧 DAILY_ORDER_COUNT を1実行単位と分かる名前に変更する案 |
| PRICE_UPDATES | 1。旧 DAILY_PRICE_UPDATES の改名案 |
| FLASH_SALE_ORDERS | 0。旧 DAILY_FLASH_SALE_ORDERS の改名案 |

FORCE_GENERATOR、INITIAL_SNAPSHOT_DONE、dev/prod 切替用 DBT_TARGET は不要。環境変数の改名は暫定であり、実装時に利用箇所と .env.example を揃える。

## 9. Dev Container【Mac】

.devcontainer/dbt/ に Dockerfile、compose.yml、devcontainer.json、post-create.sh を置く予定。表示名 dap2-dbt。

Mac の VS Code でローカルのプロジェクトを開き、同じ Mac の Docker 上で Dev Container を起動する。Remote SSH や Raspberry Pi への接続は行わない。

- dbt Power User の拡張 ID、対応版、Python/dbt 実行パスを確認する。
- post-create.sh は依存準備に限定し、dbt init、モデル作成、snapshot を自動実行しない。
- ソース、target/、logs/ は必要に応じホスト側へ保存し、コンテナ再作成で失わないようにする。
- dev/prod 用の Dev Container を別々に作らない。

## 10. 流用元・互換性検証【R09】

流用予定元：trickle-labs/pg-trickle。

| 元ファイル | 予定変更 |
|---|---|
| demo/generator/scenarios/ecommerce.py | generator/ecommerce.py。fetch_lookups、insert_order、update_product_price、sample_price を活用し、無限ループを除去。注文時刻を生成区間から渡す |
| demo/generator/requirements.txt | 依存候補として参照し、Mac 上の採用コンテナで検証 |
| demo/postgres/ecommerce/01_schema.sql | postgres/init/01_schema.sql。拡張作成を除去。初期注文と前回成功時刻の状態を調整 |
| stream tables、dashboard、公式 Compose、拡張本体 | 使用しない |

流用元コミットを固定し、LICENSE/NOTICE と必要な表示を確認する。元コードとの差分を記録する。指定 SQL 本文の確認とライセンス文書の配置は未完了。

「Mac で問題が起きない」は検証要件として扱い、未実施の動作保証はしない。実装時に次を確認する。

- 利用 Mac の CPU に対応した PostgreSQL/Python コンテナの起動。
- DB ドライバーと dbt Core/adapter の依存解決・導入。
- Dev Container と dbt Power User の起動・実行パス。
- cron から Docker を起動でき、対話実行と同じ設定を使用すること。
- DBeaver の localhost 接続と、ホスト側ポートの競合有無。

具体的な依存版は元案を候補として扱い、動作確認後に確定する。dbt プロジェクトの初期化や学習モデル作成はこの互換性確認のためにも代行しない。

## 11. 受入条件

- Mac 上のみで DB・生成処理・Dev Container を利用できる。
- 作成リソース名に dap2 が付き、既存 dap とコンテナ・ネットワーク・ボリューム・ホスト公開ポートが競合しない。
- dap2 の起動・停止・再作成で既存 dap のコンテナ・データ・cron 登録を変更しない。
- 初期の業務テーブル件数が 8 / 15 / 30 / 50 / 15 である。
- dbt プロジェクトや snapshot がなくても生成が成功する。
- 既定の生成処理を2回連続実行すると、同じ日でも注文が合計20件増える。
- 各回で設定数の価格更新を試みる。丸めで同値となる場合の扱いは決定した規則に従う。
- 注文時刻が前回成功時刻より後、今回基準時刻以下となる。
- 生成失敗時には注文・価格・前回成功時刻が部分更新されない。ID の欠番は許容する。
- snapshot 未実行・失敗でも、その後の生成が止まらない。
- cron の頻度を変更すると、その頻度で毎回追加・更新される。
- DBeaver で localhost 接続できる。reader を用意する場合は読み取り専用である。
- ログがコンテナ削除後も残り、失敗を終了コードで識別できる。
- dbt のモデル・incremental・snapshot の成果確認は、利用者がそれらを実装した後の学習項目とする。

## 12. 判断記録・残る細部

| 日付 | 決定 |
|---|---|
| 2026-11-07 | R01：dlt 不使用、Python から lake へ直接生成・追加・更新 |
| 2026-11-07 | 全体を Mac に変更。開発＝本番。Dev Container も Mac |
| 2026-11-07 | R02/R04/R05：毎回生成し、日付キーや snapshot 成否による抑止を廃止 |
| 2026-11-07 | R03：dbt は未作成で開始。利用者が初期から実装 |
| 2026-11-07 | R06：接続ユーザーは共通 |
| 2026-11-07 | R08：前回実行後〜今回実行時の範囲からランダム生成。注文時刻と解釈して具体化 |
| 2026-11-07 | R09：Mac 互換性を優先。実装時の検証を受入条件に追加 |
| 2026-11-07 | 定期実行：Mac cron → run_daily.sh → コンテナ内の generator/daily.py に確定。ホスト側 Python ラッパーは不要 |

| 2026-11-07 | 正式名称 SmallDataAnalyticsPlatform2、略称 dap2。作成リソースを dap2 で識別し、既存 dap との干渉を避ける。ホスト公開ポートは暫定15432 |

残る細部：ホスト公開ポートの空き確認、初期注文の期間（暫定24時間）、単一 target/schema 名（暫定 local/analytics）、前回成功時刻の保存方式（暫定 generator_state）、通貨・丸め、選択確率、同価格更新、依存バージョン。

## 参考資料

- dbt snapshots：https://docs.getdbt.com/docs/build/snapshots
- dbt custom schemas：https://docs.getdbt.com/docs/build/custom-schemas
- dbt build：https://docs.getdbt.com/reference/commands/build
- 流用予定元：https://github.com/trickle-labs/pg-trickle
- 指定 SQL（本文未確認）：https://github.com/trickle-labs/pg-trickle/blob/main/demo/postgres/ecommerce/01_schema.sql
