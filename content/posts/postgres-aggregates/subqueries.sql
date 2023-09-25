EXPLAIN (
  ANALYZE,
  COSTS,
  VERBOSE,
  BUFFERS
)
SELECT
  products.id,
  products.name,
(
    SELECT
      COUNT(id)
    FROM
      reviews
    WHERE
      product_id = products.id) AS num_reviews,
(
    SELECT
      COUNT(id)
    FROM
      orders
    WHERE
      product_id = products.id) AS num_orders
FROM
  products;

-- WHERE
--   products.name ilike '%0';
