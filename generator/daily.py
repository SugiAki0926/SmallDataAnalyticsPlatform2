"""注文を追加し、価格を更新する。"""

import os
import random
import sys

import psycopg2
from ecommerce import fetch_lookups, insert_order, sample_price, update_product_price


def env_int(name: str, default: int) -> int:
    return int(os.environ.get(name, str(default)))


def random_ordered_at(t_prev, t_now):
    """t_prev より後、t_now 以下の一様ランダムな時刻。"""
    return t_prev + (t_now - t_prev) * (1 - random.random())


def main() -> None:
    order_count = env_int("ORDER_COUNT", 10)
    price_updates = env_int("PRICE_UPDATES", 1)
    flash_sale_orders = env_int("FLASH_SALE_ORDERS", 0)

    conn = psycopg2.connect(
        host=os.environ["POSTGRES_HOST"],
        port=os.environ["POSTGRES_PORT"],
        dbname=os.environ["POSTGRES_DB"],
        user=os.environ["POSTGRES_USER"],
        password=os.environ["POSTGRES_PASSWORD"],
    )
    try:
        conn.autocommit = False
        with conn.cursor() as cur:
            cur.execute("SET search_path TO lake")
            cur.execute("SELECT last_success_at FROM generator_state WHERE id = 1 FOR UPDATE")
            state = cur.fetchone()
            if state is None:
                raise RuntimeError("generator_state の行がありません")
            t_prev = state[0]
            cur.execute("SELECT clock_timestamp()")
            t_now = cur.fetchone()[0]
            if t_now <= t_prev:
                raise RuntimeError("有効な生成区間がありません")
            cur.execute("SELECT count(*) FROM orders")
            orders_before = cur.fetchone()[0]

        customers, products, _categories = fetch_lookups(conn)
        if price_updates > len(products):
            raise RuntimeError(f"PRICE_UPDATES={price_updates} が商品数 {len(products)} を超えています")

        # id 順の先頭15%の顧客、先頭20%の商品だけを通常注文に使う。
        active_customers = customers[: max(1, int(len(customers) * 0.15))]
        active_products = products[: max(1, int(len(products) * 0.20))]

        inserted = []
        for _ in range(order_count):
            customer_id = random.choice(active_customers)
            # SELECT p.id, p.base_price, pc.current_price, p.category_id
            product_id, _base, current, _category_id = random.choice(active_products)
            quantity = random.randint(1, 2)
            unit_price = sample_price(current)
            ordered_at = random_ordered_at(t_prev, t_now)
            order_id = insert_order(conn, customer_id, product_id, quantity, unit_price, ordered_at)
            inserted.append((order_id, customer_id, product_id, quantity, round(unit_price, 2), ordered_at))

        for _ in range(flash_sale_orders):
            customer_id = random.choice(customers)
            product_id, _base, current, _category_id = random.choice(products)
            quantity = random.randint(1, 2)
            unit_price = current * random.uniform(0.70, 0.85)
            ordered_at = random_ordered_at(t_prev, t_now)
            order_id = insert_order(conn, customer_id, product_id, quantity, unit_price, ordered_at)
            inserted.append((order_id, customer_id, product_id, quantity, round(unit_price, 2), ordered_at))

        changes = []
        for product_id, base, current, _category_id in random.sample(products, price_updates):
            new_price = update_product_price(conn, product_id, base, t_now)
            changes.append((product_id, base, current, new_price))

        with conn.cursor() as cur:
            cur.execute("UPDATE generator_state SET last_success_at = %s WHERE id = 1", (t_now,))
        conn.commit()
    except Exception as exc:
        conn.rollback()
        print(f"[GENERATOR] failed: {exc}", file=sys.stderr, flush=True)
        raise SystemExit(1) from exc
    finally:
        conn.close()

    ordered_ats = [row[5] for row in inserted]
    print(
        f"orders_before={orders_before} inserted={len(inserted)} "
        f"id={inserted[0][0]}..{inserted[-1][0]} "
        f"t_prev={t_prev.isoformat()} t_now={t_now.isoformat()} "
        f"ordered_at={min(ordered_ats).isoformat()}..{max(ordered_ats).isoformat()}",
        flush=True,
    )
    for order_id, customer_id, product_id, quantity, unit_price, ordered_at in inserted:
        print(
            f"[ORDER] id={order_id} customer={customer_id} product={product_id} "
            f"qty={quantity} unit_price={unit_price:.2f} ordered_at={ordered_at.isoformat()}",
            flush=True,
        )
    for product_id, base, old, new in changes:
        print(
            f"[PRICE] product={product_id} base={base:.2f} old={old:.2f} new={new:.2f}",
            flush=True,
        )


if __name__ == "__main__":
    main()
