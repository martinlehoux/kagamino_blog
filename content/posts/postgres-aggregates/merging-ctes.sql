EXPLAIN (
  ANALYZE,
  COSTS,
  VERBOSE,
  BUFFERS
) WITH product_reviews AS (
  SELECT
    product_id,
    COUNT(id) AS num_reviews
  FROM
    reviews
  GROUP BY
    product_id),
  product_orders AS (
    SELECT
      product_id,
      COUNT(id) AS num_orders
    FROM
      orders
    GROUP BY
      product_id
)
  SELECT
    products.id,
    products.name,
    COALESCE(product_reviews.num_reviews, 0) AS num_reviews,
  COALESCE(product_orders.num_orders, 0) AS num_orders
FROM
  products
  LEFT JOIN product_reviews ON products.id = product_reviews.product_id
  LEFT JOIN product_orders ON products.id = product_orders.product_id;

-- WHERE
--   products.id % 10 = 0
