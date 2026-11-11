-- 出典: trickle-labs/pg-trickle
-- コミット: 2ceaf621924c143b84e50c1b3d5a8f6d953fb293
-- ライセンス: Apache-2.0
-- 元ファイル: demo/postgres/ecommerce/01_schema.sql
-- 変更: 拡張とストリームテーブルを除く。schema lake。初期注文は1行ごとに顧客・商品を選び、数量1〜2、直前24時間。
--       業務テーブルに created_at / updated_at を置く。価格更新では product_catalog.updated_at だけを進める。
-- ── Base tables ───────────────────────────────────────────────────────────────
CREATE SCHEMA IF NOT EXISTS lake;
SET search_path TO lake;

CREATE TABLE categories (
    id         BIGSERIAL PRIMARY KEY,
    name       TEXT        NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE products (
    id          BIGSERIAL PRIMARY KEY,
    name        TEXT          NOT NULL,
    category_id BIGINT        NOT NULL REFERENCES categories(id),
    base_price  NUMERIC(10,2) NOT NULL,
    created_at  TIMESTAMPTZ   NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ   NOT NULL DEFAULT now()
);

CREATE TABLE customers (
    id         BIGSERIAL PRIMARY KEY,
    name       TEXT        NOT NULL,
    country    TEXT        NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 1行が1商品の購入。ordered_at は出来事の時刻。created_at / updated_at は行を記録した時刻。
CREATE TABLE orders (
    id          BIGSERIAL        PRIMARY KEY,
    customer_id BIGINT           NOT NULL REFERENCES customers(id),
    product_id  BIGINT           NOT NULL REFERENCES products(id),
    quantity    INT              NOT NULL DEFAULT 1,
    unit_price  NUMERIC(10,2)   NOT NULL,
    ordered_at  TIMESTAMPTZ      NOT NULL DEFAULT now(),
    created_at  TIMESTAMPTZ      NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ      NOT NULL DEFAULT now()
);

-- 商品ごとの現在価格。dbt snapshot は updated_at の変化を見る。
-- 価格更新では updated_at だけを進め、created_at は変えない。
CREATE TABLE product_catalog (
    product_id    BIGINT        PRIMARY KEY REFERENCES products(id),
    current_price NUMERIC(10,2) NOT NULL,
    created_at    TIMESTAMPTZ   NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ   NOT NULL DEFAULT now()
);

-- ── Seed data: categories ────────────────────────────────────────────────────

INSERT INTO categories (name) VALUES
    ('Electronics'),
    ('Clothing'),
    ('Home & Garden'),
    ('Books'),
    ('Sports'),
    ('Food & Drink'),
    ('Beauty'),
    ('Toys');

-- ── Seed data: products ──────────────────────────────────────────────────────

INSERT INTO products (name, category_id, base_price) VALUES
    ('Wireless Headphones',  1,  79.99),
    ('Smart Watch',          1, 199.99),
    ('USB-C Hub',            1,  39.99),
    ('Running Shoes',        5,  89.99),
    ('Yoga Mat',             5,  34.99),
    ('T-Shirt',              2,  19.99),
    ('Winter Jacket',        2, 119.99),
    ('Coffee Maker',         3,  59.99),
    ('Plant Pot Set',        3,  24.99),
    ('JavaScript Book',      4,  44.99),
    ('Cookbook',             4,  29.99),
    ('Protein Powder',       6,  49.99),
    ('Face Moisturizer',     7,  32.99),
    ('LEGO Set',             8,  64.99),
    ('Puzzle 1000pc',        8,  22.99);

-- ── Seed data: customers (30 rows) ──────────────────────────────────────────

INSERT INTO customers (name, country) VALUES
    ('Alice Chen',        'US'),
    ('Bob Kumar',         'UK'),
    ('Carlos Rivera',     'MX'),
    ('Diana Park',        'KR'),
    ('Ethan Williams',    'US'),
    ('Fatima Al-Rashid',  'AE'),
    ('George Müller',     'DE'),
    ('Hannah Johansson',  'SE'),
    ('Ivan Petrov',       'RU'),
    ('Julia Santos',      'BR'),
    ('Kenji Tanaka',      'JP'),
    ('Layla Hassan',      'EG'),
    ('Marco Rossi',       'IT'),
    ('Nadia Okonkwo',     'NG'),
    ('Oscar Lindberg',    'SE'),
    ('Priya Sharma',      'IN'),
    ('Quentin Dubois',    'FR'),
    ('Rachel Kim',        'KR'),
    ('Samuel Adeyemi',    'NG'),
    ('Tanya Morozova',    'RU'),
    ('Ursula Weber',      'DE'),
    ('Victor Huang',      'CN'),
    ('Wendy Thompson',    'US'),
    ('Xavier Patel',      'IN'),
    ('Yuki Nakamura',     'JP'),
    ('Zara Ahmed',        'PK'),
    ('Aaron Berg',        'US'),
    ('Beatriz Oliveira',  'BR'),
    ('Chen Wei',          'CN'),
    ('Deepak Nair',       'IN');

-- ── Seed data: product_catalog (starts at base_price) ───────────────────────

INSERT INTO product_catalog (product_id, current_price)
SELECT id, base_price FROM products;

-- ── Seed orders (primes stream tables with initial data) ─────────────────────
-- 初期50注文。1行が1商品。顧客・商品は行ごとに1回だけ選ぶ。
INSERT INTO orders (customer_id, product_id, quantity, unit_price, ordered_at)
SELECT
    picked.customer_id,
    p.id,
    picked.quantity,
    p.base_price * picked.factor,
    now() - (random() * INTERVAL '24 hours')
FROM (
    SELECT
        (floor(random() * 30) + 1)::bigint AS customer_id,
        (floor(random() * 15) + 1)::bigint AS product_id,
        (floor(random() * 2) + 1)::int AS quantity,
        (0.9 + random() * 0.2) AS factor
    FROM generate_series(1, 50)
) AS picked
JOIN products AS p ON p.id = picked.product_id;

-- 初期化時刻を次回生成の t_prev にする。now() はこのスクリプトのトランザクション開始時刻で、
-- 上の初期注文が使った基準時刻と同じ。
CREATE TABLE generator_state (
    id              SMALLINT PRIMARY KEY CHECK (id = 1),
    last_success_at TIMESTAMPTZ NOT NULL
);

INSERT INTO generator_state (id, last_success_at)
VALUES (1, now());
