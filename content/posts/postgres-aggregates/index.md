---
title: "Efficiente PostgreSQL Aggregations"
draft: true
date:
description: "Diving into PostgreSQL query plans to improve our tooling"
categories:
  - PostgreSQL
---

I recently stumbled upon a problem while crafting queries for PostgreSQL at work. What appeared to be be a simple problem to solve at first glance turned out to take many hours of refining. I also found it weird to not easily find accessible knowledge about this on the Internet. I decided to simplify the problem to its core and to write calmly an article of my findings working it through.

Here is the simpler version of the problem:

- We a have a simple schema
- We want to make some efficient computations on multiples tables
  - We have 10k products
  - Each product has a mean of 100 orders, which makes for 1M orders
  - Each product has a mean of 10 reviews, which make for 100k reviews
- We want to build a UI where we display a list of products, along with their number of reviews, and their number of orders
- We only have basic indices on the foreign keys for a start

By the end of this reading, I hoope you will be able to:

- Analyze a slow query with easy to use tools
- Understand in what order will the different parts of a query be executed

## 1. Aggregation

My first approach to this problem was to use tools I was taught when learning SQL at school. If I want to summarize some information, aggregations are the way to go, right?

<!-- {{< highlight sql >}} -->

```sql
SELECT
  products.id AS product_id,
  COUNT(reviews.id) AS num_reviews
FROM
  products
LEFT JOIN reviews ON reviews.product_id = products.id
GROUP BY
  products.id;
```

<!-- {{</ highlight >}} -->

With the above query, I get a single row for each product, with the correct count of reviews for each. Easy, isn’t it? I just had to use this pattern on several joins

```sql
SELECT
  products.id AS product_id,
  COUNT(reviews.id) AS num_reviews,
  COUNT(orders.id) AS num_orders
FROM
  products
  LEFT JOIN reviews ON reviews.product_id = products.id
  LEFT JOIN orders ON orders.product_id = products.id
GROUP BY
  products.id;
```

But of course it’s not always that easy. This query give the wrong results, because before grouping and aggregating the rows, you get a single row for every couple of order and review for each product. You should quickly see that `num_reviews` and `num_orders` are the same, and have a mean value of 1000 instead of 100 or 10 as stated in the introduction.

```sql
SELECT
  products.id AS product_id,
  COUNT(DISTINCT reviews.id) AS num_reviews,
  COUNT(DISTINCT orders.id) AS num_orders
FROM
  products
  LEFT JOIN reviews ON reviews.product_id = products.id
  LEFT JOIN orders ON orders.product_id = products.id
GROUP BY
  products.id;
```

Adding the `DISTINCT` keyword here fixes this behaviour, and we finally get what we were looking for. Note that this fix only works here because the aggregation function is `COUNT`: it would not have worked if we were computing the average review rating.

No that we found an obvious way to compute the correct result, let’s take a look at performances.

> 💡 Quick disclaimer: I am in no way making benchmarks for different query patterns in PostgreSQL. The differences I show in this article are wide enough, alongside the query plans, to understand how the PostgreSQL query engine works and in what way it affects performance.

```
Benchmark 1: psql postgres://postgres@localhost:5432/postgres -f aggregation.sql
  Time (mean ± σ):      1.622 s ±  0.028 s    [User: 0.008 s, System: 0.005 s]
  Range (min … max):    1.590 s …  1.666 s    10 runs
```

On my computer, with the data provided in the introduction, I measured this query **takes 1622ms** to execute. This seems too slow for a “web app” usage where you would need to query this data on demand for a user.

<!-- Reanalyse plan because of time diff (2.4 -> 1.6) -->

Using Dalibo to understand the query plans produced by analysing this query, we can see what are the most costly parts of the query:

![Query plan for the aggregation query on several joins](aggregation.png)

- On the right an index scan taking 300ms, and the intermediate materialization taking 300ms
- The merge join of 10M rows (size of reviews x products)

We can guess from this plan that all the data is merged into an enormous intermediate table, which is then processed for computing our aggregations. Let’s take these insights into account and try building a more efficient version.

## 2. Subqueries

We know that we want to avoid merging all the data together before making computations, because it adds a lot of memory pressure that slows the whole pipeline.

Going all the way to the opposite way of thinking, we can simply make a subquery to compute the two counts for each one of the products.

```sql
SELECT
  products.id,
  products.name,
  (
    SELECT count(id)
    FROM reviews
    WHERE product_id = products.id
  ) as num_reviews,
  (
    SELECT count(id)
    FROM orders
    WHERE product_id = products.id
  ) as num_orders
FROM
  products;
```

As a side effect, we can see that rewriting the query this way adds independence, and we don’t need to use `DISTINCT` to avoid counting some rows several times.

```
Benchmark 1: psql postgres://postgres@localhost:5432/postgres -f subqueries.sql
  Time (mean ± σ):     607.0 ms ±   5.7 ms    [User: 16.5 ms, System: 4.1 ms]
  Range (min … max):   598.4 ms … 618.9 ms    10 runs
```

This query **takes now 607ms**. Sounds like a good speed-up

When we analyse the new query plan, we can see some major differences:

![Query plan for the subqueries](subqueries.png)

There are now subplans: because the subqueries reference a column of the outer query (`products.id`), these must be run for each row that is found in `products`. This is shown by the keywords `loops: 10000`. This is called a **correlated subquery**.

These queries, even if numerous, are highly efficient because they can use the indexes we created to quickly find to corresponding rows: this is what the Bitmap Index Scan and Bitmap Heap Scan show.

## 3. Merging CTEs

We have seen two ways to think about this problem, both very different. What would be a better query is a query that avoids this enormous intermediate table, but also avoids having too many loops.

One way to achieve this is to split our computation into several parts. Basically, we can compute separately the reviews count and the orders count, because each aggregation is independent. We will have subqueries, but this time uncorrelated, so they will run only once each. We can use the **Common Table Expression** pattern to make it easier to read. Then in a final stage, we combine the results of our aggregations.

```sql
WITH product_reviews AS (
  SELECT
    product_id,
    count(id) AS num_reviews
  FROM
    reviews
  GROUP BY
    product_id
),
product_orders AS (
  SELECT
    product_id,
    count(id) AS num_orders
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
```

```
Benchmark 1: psql postgres://postgres@localhost:5432/postgres -f merging-ctes.sql
  Time (mean ± σ):      90.3 ms ±   2.4 ms    [User: 14.1 ms, System: 3.7 ms]
  Range (min … max):    85.8 ms …  94.5 ms    32 runs
```

**This query takes 90ms.**

> In a previous version, I forgot to remove the distinct keywords. It added useless complexity to the query by using all those index scans, whereas we needed all data.

One requirement for this usage is that the group by is on the product id : no need to load the product to group rows together. For instance, if we wanted to group by the product creation date, it would require intermediate join on the product table.

What happens?

- Get all the reviews, then aggregate by product id in one pass (HashAggregate)
- Same goes for orders, but width the addition of parallelism (cost CPU, but reduce time)

![Query plan for the merged CTEs query](merging-ctes.png)

## 4. There is no silver bullet

Now that we found a query that executes in 90ms, compared to the initial 1622ms, it seems that we found a good pattern.

But the last query has a drawback that the previous examples do not show: the two first stages have no clues about the products they are aggregating on.

If we slightly change the problem requirements, such as we only want to compute on a subsets of the products, this last query will still compute the aggregations over all reviews and orders, but drop most of the results in the last stage.

We can show this by adding a modulo filter on the product_id to only select 10% of the products, randomly. We can see that the two first queries perform almost linearly better, when the last one has a negligible improvement

| Query       | Time 100% (ms) | Time 10% (ms) |
| ----------- | -------------- | ------------- |
| Aggregation | 1622           | 184           |
| Subquery    | 607            | 69            |
| Merged CTE  | 90             | 75            |

## Wrapping up

- Avoid queries which use aggregation functions on several "directions": you will likely shoot yourself in the foot and obtain wrong results
- When fetching a lot of data, it is efficient to aggregate each "direction" alone, before mergin all results together with the main table: it will leverage parallelism and reduce the memory used
- When selecting only a subset of the main table, using subqueries will see the most impressive speed gains (if the filter depends on the main table data: filtering products based on the number of reviews they received will append after having computed all the data)

## Resources

- [Hyperfine](https://github.com/sharkdp/hyperfine) for benchmarking
- [Dalibo Explain](https://explain.dalibo.com/) for query plan analysis
