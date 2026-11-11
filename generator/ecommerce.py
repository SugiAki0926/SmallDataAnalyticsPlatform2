"""
下記の通り、pg-trickleのサンプルコードを流用しています。
流用元: trickle-labs/pg-trickle demo/generator/scenarios/ecommerce.py
コミット: 2ceaf621924c143b84e50c1b3d5a8f6d953fb293
ライセンス: Apache-2.0
無限ループと周期実行は移していない。1回分の呼び出しは daily.py が行う。
"""

import random

# 通常注文の販売単価は、その時点の current_price の ±10%。
PRICE_VARIANCE = 0.10

# 価格更新は base_price の ±10%。
PRICE_DRIFT_PCT = (-0.10, 0.10)


def fetch_lookups(conn):
    with conn.cursor() as cur:
        cur.execute("SELECT id FROM customers ORDER BY id")
        customers = [row[0] for row in cur.fetchall()]

        cur.execute("""
            SELECT p.id, p.base_price, pc.current_price, p.category_id
            FROM products p
            JOIN product_catalog pc ON pc.product_id = p.id
            ORDER BY p.id
        """)
        products = [(row[0], float(row[1]), float(row[2]), row[3]) for row in cur.fetchall()]

        cur.execute("SELECT id FROM categories ORDER BY id")
        categories = [row[0] for row in cur.fetchall()]

    return customers, products, categories


def update_product_price(conn, product_id: int, base_price: float, updated_at) -> float:
    """現在価格を基準価格の ±10% 以内に更新する。updated_at は今回の基準時刻。"""
    lo = base_price * (1 + PRICE_DRIFT_PCT[0])
    hi = base_price * (1 + PRICE_DRIFT_PCT[1])
    new_price = round(random.uniform(lo, hi), 2)
    with conn.cursor() as cur:
        cur.execute(
            """
            UPDATE product_catalog
            SET current_price = %s, updated_at = %s
            WHERE product_id = %s
            """,
            (new_price, updated_at, product_id),
        )
    return new_price


def insert_order(
    conn,
    customer_id: int,
    product_id: int,
    quantity: int,
    unit_price: float,
    ordered_at,
) -> int:
    with conn.cursor() as cur:
        cur.execute(
            """
            INSERT INTO orders (customer_id, product_id, quantity, unit_price, ordered_at)
            VALUES (%s, %s, %s, %s, %s)
            RETURNING id
            """,
            (customer_id, product_id, quantity, round(unit_price, 2), ordered_at),
        )
        return cur.fetchone()[0]


def sample_price(current_price: float) -> float:
    variance = current_price * PRICE_VARIANCE
    return max(0.01, current_price + random.uniform(-variance, variance))
