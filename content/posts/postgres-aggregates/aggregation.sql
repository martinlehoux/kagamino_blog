EXPLAIN (
  ANALYZE,
  COSTS,
  VERBOSE,
  BUFFERS
)
SELECT
  products.id AS product_id,
  products.name AS product_name,
  COUNT(DISTINCT reviews.id) AS num_reviews,
  COUNT(DISTINCT orders.id) AS num_orders
FROM
  products
  LEFT JOIN reviews ON reviews.product_id = products.id
  LEFT JOIN orders ON orders.product_id = products.id
  -- WHERE
  --   products.id % 10 = 0
GROUP BY
  products.id;

