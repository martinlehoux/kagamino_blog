---
title: "Comparing aggregation between EdgeDB and Postgres"
draft: true
date: 2024-07-15
description: "EdgeDB is a layer above Postgres, as it uses it as the underlying engine. How can we harness the power of Postgres through this interface?"
categories:
  - PostgreSQL
---

I discoverd [EdgeDB](https://www.edgedb.com/) in one of the newsletters I follow.
When I saw it proposes an more expressive interface over a PostgreSQL database, I thought it would be interesting to see if such an interface made it possible to tweak a query the same way I did in my previous [article on aggregations on Postgres]({{<ref "posts/postgres-aggregates">}}).

Let's embark on my journey for this investigation! I'll show you how to replicate the benchmark setup (there were a few quirks!), what queries to build to replicate the loads from my last post, and a few thoughts to try and explain the results.

The EdgeDB documentation is quite good, and it's really easy to get started with it using `npx`.
This will install both the client and the server.

_Just as a reminder: I have no claim on the validity of these benchmarks. There is no control on the resources allocated to each server, or the Postgres settings used in this post or the last one. But the orders of magnitude are already telling us a lot, I think._

## First attempt {#first-attempt}

I don't know anything about EdgeDB prior to writing this post, but the concepts are easy to grasp and with a little trial and error, I am able to write code that makes sense (even if I am not able to comprehend it, as you will see).

As a reminder, here is the SQL schema I used in the previous post:

```sql
CREATE TABLE products(
  id serial PRIMARY KEY,
  name varchar(255) NOT NULL,
  description text,
  price numeric(10, 2) NOT NULL,
  created_at timestamp NOT NULL DEFAULT NOW()
);
CREATE TABLE orders(
  id serial PRIMARY KEY,
  order_date date NOT NULL,
  customer_name text NOT NULL,
  product_id integer NOT NULL REFERENCES products(id)
);
CREATE TABLE reviews(
  id serial PRIMARY KEY,
  review_date timestamp NOT NULL,
  comment text NOT NULL,
  product_id integer NOT NULL REFERENCES products(id)
);
```

With a little help from Github Copilot, here is the EdgeQL schema I end up with (sorry for no syntax highlighting):

```edgeql
module default {
  type Product {
    required name: str;
    required description: str;
    required price: decimal;
    required created_at: datetime {
      default := datetime_current();
    }
    multi orders: Order;
    multi reviews: Review;
  }
  type Order {
    required order_date: datetime;
    required customer_name: str;
  }
  type Review {
    required review_date: datetime;
    required comment: str;
  }
}
```

Then the script to generate the data: the syntax is a little bit different, but EdgeQL has variables and for loops so you can write some pretty expressive code.
The main difficulty is that links must use entities, where in Postgres you can use the ID directly: you have to run subqueries in EdgeQL.
You might notice the data is a little bit different: there are not exactly 1M orders and 100k reviews, but each product get a random number of each such as we would have around these numbers in total at the end.

```edgeql
for i in (select range_unpack(range(0, 10_000)))
  insert Product {
    name := 'product_' ++ <str>i,
    description := 'This is a product description.',
    price := <decimal>(random() * 1000 + 1),
    orders := (
      for j in (select range_unpack(range(0, <int64>(random() * 20 + 1))))
        insert Order {
          order_date := datetime_current(),
          customer_name := 'customer_' ++ <str>j,
        }
    ),
    reviews := (
      for j in (select range_unpack(range(0, <int64>(random() * 200 + 1))))
        insert Review {
          review_date := datetime_current(),
          comment := 'Comment for review #' ++ <str>j,
        }
    )
  }
```

With the correct data, I can then benchmark the most idiomatic EdgeQL query to solve our previous problem:

> We want to build a UI where we display a list of products, along with their number of reviews, and their number of orders

EdgeQL does fulfill it's claim on expressiveness: the query is obvious and very short to write:

```edgeql
select Product {
  id,
  order_count := count(.orders),
  review_count := count(.reviews)
};
```

```text
Attempt 1: npx edgedb query "select Product { id, order_count := count(.orders), review_count := count(.reviews) };"
  Time (mean ± σ):      1.576 s ±  0.036 s    [User: 0.629 s, System: 0.122 s]
  Range (min … max):    1.530 s …  1.637 s    10 runs
```

This result (1.576 s ± 0.036 s) is quite interesting, because it is very close to the result of [Part 1 of the previous post]({{<ref "posts/postgres-aggregates#1.aggregation">}}) (1.622 s ± 0.028 s). So my first conclusion is that EdgeDB converts my EdgeQL query into an equivalent of my first naive approach.

## Fixing my schema mistakes {#fixing-schema}

Before writing this article and it's conclusion, I want to check the believability of my results with the community.
I don't know a lot about EdgeDB, so maybe someone will point a mistake that would invalidate my results.

As I expected, [@winnerlein](https://github.com/winnerlein) explains to me in the [Github discussion](https://github.com/edgedb/edgedb/discussions/7506) that my use of `multi` in the schema involves the creation of a join table in Postgres.

EdgeDB has a nice introspection interface: when I use `npx edgedb instance credentials --insecure-dsn`, I get the database connection URL, and it appears you can connect to it with a postgres client (I use [pgcli](https://github.com/dbcli/pgcli)). I can inspect and verify what [@winnerlein](https://github.com/winnerlein) tells me:

| Schema | Name            | Type  | Owner    |
| ------ | --------------- | ----- | -------- |
| public | Order           | table | postgres |
| public | Product         | table | postgres |
| public | Product.orders  | table | postgres |
| public | Product.reviews | table | postgres |
| public | Review          | table | postgres |

They suggest another EdgeQL schema:

```edgeql
module default {
  type Product {
    required name: str;
    required description: str;
    required price: decimal;
    required created_at: datetime {
      default := datetime_current();
    }
  }
  type Order {
    required order_date: datetime;
    required customer_name: str;
    required product: Product;
  }
  type Review {
    required review_date: datetime;
    required comment: str;
    required product: Product;
  }
}
```

I don't really understand why, but I have more trouble generating the test data for this schema. After several attempts, and syntax errors from the EdgeQL client, I end up using a simple Python script to generate the data:

```py
import random
import edgedb
from tqdm import tqdm

client = edgedb.create_client()
products = client.query("select Product { id }")
for product in tqdm(products):
    client.query(
        """
with product := (select Product filter .id = <uuid>$product_id)
for k in (select range_unpack(range(0, <int64>$range_end)))
    insert Order {
        product := product,
        order_date := datetime_current(),
        customer_name := 'customer_' ++ <str>k,
    }
""",
        range_end=random.randint(50, 150),
        product_id=product.id,
    )
    client.query(
        """
with product := (select Product filter .id = <uuid>$product_id)
for k in (select range_unpack(range(0, <int64>$range_end)))
    insert Review {
      review_date := datetime_current(),
      comment := 'Comment for review #' ++ <str>k,
      product := product
    }
""",
        range_end=random.randint(5, 15),
        product_id=product.id,
    )
```

With the data in place, we can now query it.
The query is a little different, but still quite expressive:

```edgeql
select Product {
  id,
  order_count := count(.<product[is Order]),
  review_count := count(.<product[is Review])
};
```

We can make a simple query to validate that it gives correct results, using variables:

```edgeql
with agg := (select Product { id, order_count := count(.<product[is Order]), review_count := count(.<product[is Review]) })
select {avg_order_count := math::mean(agg.order_count), avg_review_count := math::mean(agg.review_count) }
```

I get `{{avg_order_count: 100.3914, avg_review_count: 9.9634}}`, which fits our initial statistical description of the data, so I'm happy with the approach.

Let's now run the benchmark on the new data:

```text
Attempt 2: npx edgedb query "select Product { id, order_count := count(.<product[is Order]), review_count := count(.<product[is Review]) };"
  Time (mean ± σ):     806.2 ms ±  33.1 ms    [User: 605.9 ms, System: 124.4 ms]
  Range (min … max):   766.6 ms … 858.5 ms    10 runs
```

This query (or more precisely this schema) runs twice as fast (806.2 ms ± 33.1 ms) than the previous one. This is a big change, and we can see that now the performance is closer to our results from [using subqueries in the previous post]({{<ref "posts/postgres-aggregates#2.subqueries">}}) (607.0 ms ± 5.7 ms).

EdgeDB has an `edgedb analyze --expand` command, comparable to what Postgres proposes (I couldn't find a UI such as Dalibo Explain). But the default display is quite readable:

```text
──────────────────────────────────────────────────── Fine-grained Query Plan ────────────────────────────────────────────────────
   │  Time   Cost   Loops    Rows Width │ Plan Info
┬─ │ 213.6 200009     1.0 10000.0    32 │ ➊ SeqScan relation_name=Product
├┬ │  30.0    8.5 10000.0     1.0     8 │ ➋ SubqueryScan
│╰ │  30.0    8.5 10000.0     1.0     8 │ ➋ Aggregate strategy=Plain, partial_mode=Simple
│  │  30.0   8.47 10000.0    10.0    16 │ Result
│  │  20.0   8.47 10000.0    10.0    16 │ IndexScan relation_name=Review, scan_direction=Forward, index_name=Review.product index
╰┬ │ 180.0  11.48 10000.0     1.0     8 │ ➌ SubqueryScan
 ╰ │ 180.0  11.48 10000.0     1.0     8 │ ➌ Aggregate strategy=Plain, partial_mode=Simple
   │ 150.0  11.21 10000.0   100.0    16 │ Result
   │  90.0  11.21 10000.0   100.0    16 │ IndexScan relation_name=Order, scan_direction=Forward, index_name=Order.product index
```

This plan is interesting to me for two reasons:

1. We can validate that EdgeDB created the indices on the foreign key all by itself (we had to create them by hand in the postgres version)
2. We see that EdgeDB chose an approach similar to our Subquery version from Postgres: we see 10k loops, so one for each product, and we see `IndexScan` in each of these loops

So it seems that EdgeDB chooses the Subqueries approach: it makes sense to me because it is the most versatile approach. EdgeDB doesn't have as much knowledge about the data as we do, and it must make decisions that would work OK most of the time. As we saw previously, it is also more lazy when applying filters (the [Subquery beats CTE when targeting 10% or less of the data]({{<ref "posts/postgres-aggregates#filters">}}) in my case).

## Wrapping up {#conclusion}

For the kind of load we measure (aggregation on a whole dataset), it seems that EdgeDB doesn't really have a way to express the [Merging Common Table Expressions approach]({{<ref "posts/postgres-aggregates#3.ctes">}}) that performed the best on the largest dataset. One good news is that, if really needed, EdgeDB still lets you query the underlying data with Postgres, so you can fallback to the same techniques.

I am happy with my investigations on this subject: most of my intuitions came valid, so it validates my understanding of how databases work (to this day!).

Overall, it was a nice experience with EdgeQL. With no knowledge at all, it is quite easy to have something that works.

## Resources

- [EdgeDB Documentation](https://docs.edgedb.com/get-started/quickstart)
- [Github Discussion](https://github.com/edgedb/edgedb/discussions/7506)
- [pgcli](https://github.com/dbcli/pgcli)
