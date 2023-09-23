-- EXPLAIN (ANALYZE, COSTS, VERBOSE, BUFFERS)
WITH product_with_reviews AS (
  SELECT
    products.id AS product_id,
    products.name AS product_name,
    COUNT(reviews.id) AS num_reviews
  FROM
    products
    LEFT JOIN reviews ON reviews.product_id = products.id
    -- WHERE
    --   products.id % 10 = 0
  GROUP BY
    products.id,
    products.name
)
SELECT
  product_with_reviews.product_id,
  product_name,
  num_reviews,
  COUNT(id) AS num_orders
FROM
  product_with_reviews
  LEFT JOIN orders ON orders.product_id = product_with_reviews.product_id
GROUP BY
  product_with_reviews.product_id,
  product_name,
  num_reviews;

