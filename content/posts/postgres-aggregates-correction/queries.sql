-- ============================================================
-- postgres-aggregates-correction: benchmark queries
-- Run each block separately and save the EXPLAIN output.
-- ============================================================

-- -------------------------------------------------------
-- 1. Subquery — count(id) — no filter  [ORIGINAL, baseline]
-- -------------------------------------------------------
EXPLAIN (ANALYZE, COSTS, VERBOSE, BUFFERS)
SELECT
  products.id,
  products.name,
  (SELECT COUNT(id) FROM reviews WHERE product_id = products.id) AS num_reviews,
  (SELECT COUNT(id) FROM orders  WHERE product_id = products.id) AS num_orders
FROM products;


-- -------------------------------------------------------
-- 2. Subquery — count(*) — no filter   [THE FIX]
-- -------------------------------------------------------
EXPLAIN (ANALYZE, COSTS, VERBOSE, BUFFERS)
SELECT
  products.id,
  products.name,
  (SELECT COUNT(*) FROM reviews WHERE product_id = products.id) AS num_reviews,
  (SELECT COUNT(*) FROM orders  WHERE product_id = products.id) AS num_orders
FROM products;


-- -------------------------------------------------------
-- 3. CTE (merging) — count(id) — no filter
-- -------------------------------------------------------
EXPLAIN (ANALYZE, COSTS, VERBOSE, BUFFERS)
WITH product_reviews AS (
  SELECT product_id, COUNT(id) AS num_reviews
  FROM reviews
  GROUP BY product_id
),
product_orders AS (
  SELECT product_id, COUNT(id) AS num_orders
  FROM orders
  GROUP BY product_id
)
SELECT
  products.id,
  products.name,
  COALESCE(product_reviews.num_reviews, 0) AS num_reviews,
  COALESCE(product_orders.num_orders,   0) AS num_orders
FROM products
LEFT JOIN product_reviews ON products.id = product_reviews.product_id
LEFT JOIN product_orders  ON products.id = product_orders.product_id;


-- -------------------------------------------------------
-- 4. Subquery — count(*) — root filter (price > 900)
-- -------------------------------------------------------
EXPLAIN (ANALYZE, COSTS, VERBOSE, BUFFERS)
SELECT
  products.id,
  products.name,
  (SELECT COUNT(*) FROM reviews WHERE product_id = products.id) AS num_reviews,
  (SELECT COUNT(*) FROM orders  WHERE product_id = products.id) AS num_orders
FROM products
WHERE products.price > 900;


-- -------------------------------------------------------
-- 5. CTE (merging) — count(id) — root filter (price > 900)
-- -------------------------------------------------------
EXPLAIN (ANALYZE, COSTS, VERBOSE, BUFFERS)
WITH product_reviews AS (
  SELECT product_id, COUNT(id) AS num_reviews
  FROM reviews
  GROUP BY product_id
),
product_orders AS (
  SELECT product_id, COUNT(id) AS num_orders
  FROM orders
  GROUP BY product_id
)
SELECT
  products.id,
  products.name,
  COALESCE(product_reviews.num_reviews, 0) AS num_reviews,
  COALESCE(product_orders.num_orders,   0) AS num_orders
FROM products
LEFT JOIN product_reviews ON products.id = product_reviews.product_id
LEFT JOIN product_orders  ON products.id = product_orders.product_id
WHERE products.price > 900;


-- -------------------------------------------------------
-- 6. Subquery — count(*) — leaf filter (customer_name ilike '%0')
-- -------------------------------------------------------
EXPLAIN (ANALYZE, COSTS, VERBOSE, BUFFERS)
SELECT
  products.id,
  products.name,
  (SELECT COUNT(*) FROM reviews WHERE product_id = products.id) AS num_reviews,
  (SELECT COUNT(*) FROM orders  WHERE product_id = products.id AND customer_name ILIKE '%0') AS num_orders
FROM products;


-- -------------------------------------------------------
-- 7. CTE (merging) — count(id) — leaf filter (customer_name ilike '%0')
-- -------------------------------------------------------
EXPLAIN (ANALYZE, COSTS, VERBOSE, BUFFERS)
WITH product_reviews AS (
  SELECT product_id, COUNT(id) AS num_reviews
  FROM reviews
  GROUP BY product_id
),
product_orders AS (
  SELECT product_id, COUNT(id) AS num_orders
  FROM orders
  WHERE customer_name ILIKE '%0'
  GROUP BY product_id
)
SELECT
  products.id,
  products.name,
  COALESCE(product_reviews.num_reviews, 0) AS num_reviews,
  COALESCE(product_orders.num_orders,   0) AS num_orders
FROM products
LEFT JOIN product_reviews ON products.id = product_reviews.product_id
LEFT JOIN product_orders  ON products.id = product_orders.product_id;


-- ============================================================
-- DISK-THROTTLED PASS (run with Docker: shared_buffers=16MB,
-- blkio capped at 125MB/s read — see docker-compose snippet)
-- Run DISCARD ALL between queries to flush caches.
-- ============================================================

-- -------------------------------------------------------
-- D1. Subquery — count(id) — no filter  [Bitmap Heap Scan expected]
-- -------------------------------------------------------
DISCARD ALL;
EXPLAIN (ANALYZE, COSTS, VERBOSE, BUFFERS)
SELECT
  products.id,
  products.name,
  (SELECT COUNT(id) FROM reviews WHERE product_id = products.id) AS num_reviews,
  (SELECT COUNT(id) FROM orders  WHERE product_id = products.id) AS num_orders
FROM products;


-- -------------------------------------------------------
-- D2. Subquery — count(*) — no filter  [Index Only Scan expected]
-- -------------------------------------------------------
DISCARD ALL;
EXPLAIN (ANALYZE, COSTS, VERBOSE, BUFFERS)
SELECT
  products.id,
  products.name,
  (SELECT COUNT(*) FROM reviews WHERE product_id = products.id) AS num_reviews,
  (SELECT COUNT(*) FROM orders  WHERE product_id = products.id) AS num_orders
FROM products;


-- -------------------------------------------------------
-- D3. CTE (merging) — count(id) — no filter
-- -------------------------------------------------------
DISCARD ALL;
EXPLAIN (ANALYZE, COSTS, VERBOSE, BUFFERS)
WITH product_reviews AS (
  SELECT product_id, COUNT(id) AS num_reviews
  FROM reviews
  GROUP BY product_id
),
product_orders AS (
  SELECT product_id, COUNT(id) AS num_orders
  FROM orders
  GROUP BY product_id
)
SELECT
  products.id,
  products.name,
  COALESCE(product_reviews.num_reviews, 0) AS num_reviews,
  COALESCE(product_orders.num_orders,   0) AS num_orders
FROM products
LEFT JOIN product_reviews ON products.id = product_reviews.product_id
LEFT JOIN product_orders  ON products.id = product_orders.product_id;
