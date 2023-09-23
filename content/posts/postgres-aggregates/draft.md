## 4. Sequential CTEs

```sql
WITH product_with_reviews AS (
  SELECT
    products.id as product_id,
    products.name as product_name,
    count(reviews.id) AS num_reviews
  FROM
    products
    LEFT JOIN reviews ON reviews.product_id = products.id
  GROUP BY
    products.id,
    products.name
)
SELECT
  product_with_reviews.product_id,
  product_name,
  num_reviews,
  count(id) AS num_orders
FROM
  product_with_reviews
  LEFT JOIN orders ON orders.product_id = product_with_reviews.product_id
GROUP BY
  product_with_reviews.product_id,
  product_name,
  num_reviews;
```

```
Benchmark 1: psql postgres://postgres@localhost:5432/postgres -f sequential-ctes.sql
  Time (mean ± σ):     360.9 ms ±   4.5 ms    [User: 15.5 ms, System: 4.2 ms]
  Range (min … max):   355.0 ms … 369.2 ms    10 runs
```

**This query takes 361ms.**

It’s longer than the merged CTEs, basically because the hash join happens before aggregation. So we have much more data to process at the end of the pipeline.

<!-- TODO: Replace by screenshot -->

![Untitled](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/76d6a2d1-4d0d-454a-997f-18e21cf2f3a1/Untitled.png)

## 5. Going further

| Query          | Time 100% | Time 10% |
| -------------- | --------- | -------- |
| Aggregation    | 2450      | 270      |
| Merged CTE     | 90        | 80       |
| Subquery       | 650       | 60       |
| Sequential CTE | 361       | 85       |

- What happens if we filter out 10% ? 90% of products base of products table?
  - Sequential CTE would be faster, adding the filter in the beginning
  - Aggregation & Subquery too would be faster
  - Merged CTE would still do all the work, or almost (less data to process at some point)
- We can see plans that scale almost linearly : Aggregation & Subquery
- Sequential subquery does not scale as well, I don’t know why
- But Merged CTE only scales down for a small fraction, because most of the work is done without knowing what products will be selected.
- Maybe a conclusion is that there is no silver bullet: we can make queries have a small cost when done a a large queryset, compared to others, but when the queryset is much smaller, the gain will be less important than others.
- The same way as finding 1 largest element is a seq scan O(n), but finding n largest elements out of n should use a sort O(nlogn). Finding the sweet spot where to swap your algorithm is finding k such as kn ~ nlogn ⇒ k = log n. Ex: for 10k elements, if you need to find more than 10, use sort.

## TODOs and open questions

- Are there differences using different postgres versions?
- Add charts to visualize
- Traffic analytics?
- Short intro to postgres engine and query plans
