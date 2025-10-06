---
title: PostgreSQL aggregation processing speed
draft: false
date: 2025-10-06
lastmod:
description: Comparison of aggregation function speed, on the database and in a host language
categories:
  - PostgreSQL
---
## Key takeaways

**JSON is more efficient than JSONB when only reading data**

JSONB is useful for data processing, when filtering data on the database. But in this test, the higher cost of creating JSONB is not worth it, and there is also a price to convert it back to text.

**Use `composite binary` for Python data processing**

If you need to compute further in Python, the raw speed of composite binary on Postgres and the OK part in Python makes it the fastest to get data in processable data structures. You can even cast the output in a typed `NamedTuple` and won't need manual parsing

## The problem

Most of the time, the rows of a SQL query matches the domain: a list of user data, a list of product data. But sometimes, there is a sub list for each item: each user's top articles.

When a single sub list is required, several rows can be returned by joins for each root item: several rows for each user. The data is then merged in the host language.

But when there are several sub lists, there is an issue with high cardinality: each user has 15 articles, and 30 comments, and that makes 450 rows for each user, with a lot of duplicated data.

In this case, there are list aggregation functions to generate sub lists at the row level. There are several available, such as `json_agg` and `array_agg`.

**When should you use one or the other?**

After performing this article's investigation, I will implement the learnings to a central query in my day job product: a search query. Because it requires some price filtering in Python, the data loading part from SQL can be quite important. The results below show the time spent in each part of the pipeline. Overall, the changes give about a 5% boost to the query, while reducing maintenance cost. Not bad for a query I spent weeks optimising!

{{< perf-chart title="Case study" labels="Old,New" datasets="Wait (ms):emerald:1095,1100|Psycopg parsing (ms):amber:45,180|Custom parsing (ms):purple:350,140" >}}

## Data model and setup

I use a simple data model, and I can tweak the size of the dataset so that the benchmark is interesting.

The model is an `Accommodation`, that has a default price for rental, and then many `Override` that would allow to specify different prices along the year. There are 10,000 accommodations and 1,000,000 overrides.

![Data model](data-model.svg)

```sql
CREATE TABLE accommodations (
    id serial PRIMARY KEY,
    name text NOT NULL,
    default_price numeric(10, 2) NOT NULL
);

INSERT INTO accommodations (name, default_price)
SELECT
    CONCAT('accommodation_', generate_series) AS name,
    TRUNC(RANDOM() * 100 + 200) AS default_price
FROM GENERATE_SERIES(1, 10000);

CREATE TABLE overrides (
    id serial PRIMARY KEY,
    accommodation_id integer NOT NULL REFERENCES accommodations (id),
    date date NOT NULL,
    price numeric(10, 2) NOT NULL
);
ALTER TABLE overrides ADD constraint unique_dates UNIQUE (
    accommodation_id, date
);
INSERT INTO overrides (accommodation_id, date, price) SELECT
    (generate_series / 100) + 1 AS accommodation_id,
    '2025-01-01'::date + (generate_series % 100) * '3 days'::interval AS date,
    TRUNC(RANDOM() * 100 + 200) AS price
FROM GENERATE_SERIES(1, 999999);
```

## Postgres query engine performance

The first question is: **what is the fastest query?**

The three data types used are:
- `composite`, which is like a type safe tuple in any programming language
- `json`, which represent a JSON value and is stored as text
- `jsonb`, also represents a JSON value, but stored in an optimised format for querying

Let's take a look at the five queries:

**Composite query**

```sql
SELECT
    accommodation_id,
    array_agg((date, price)) AS daily_configs
FROM overrides
WHERE '[2025-07-01,2025-08-01)'::daterange @> date
GROUP BY overrides.accommodation_id
```

**JSON object query**

```sql
SELECT
    accommodation_id,
    json_agg(json_build_object(
        'date', date,
        'price', price::text
    )) AS daily_configs
FROM overrides
WHERE '[2025-07-01,2025-08-01)'::daterange @> date
GROUP BY overrides.accommodation_id
```

**JSON array query**

```sql
SELECT
    accommodation_id,
    json_agg(json_build_array(date, price::text)) AS daily_configs
FROM overrides
WHERE '[2025-07-01,2025-08-01)'::daterange @> date
GROUP BY overrides.accommodation_id
```

**JSONB object query**

```sql
SELECT
    accommodation_id,
    jsonb_agg(jsonb_build_object(
        'date', date,
        'price', price::text
    )) AS daily_configs
FROM overrides
WHERE '[2025-07-01,2025-08-01)'::daterange @> date
GROUP BY overrides.accommodation_id
```

**JSONB array query**

```sql
SELECT
    accommodation_id,
    jsonb_agg(jsonb_build_array(date, price::text)) AS daily_configs
FROM overrides
WHERE '[2025-07-01,2025-08-01)'::daterange @> date
GROUP BY overrides.accommodation_id
```

They look pretty similar.

I run these five queries with `EXPLAIN (ANALYZE, COSTS, VERBOSE, BUFFERS)`, and I can note their total time, alongside the different nodes duration in the plan.

{{< perf-chart title="PostgreSQL Query Performance" labels="composite,json array,jsonb array,json object,jsonb object" datasets="Seq Scan (ms):emerald:39,37,35,40,40|HashAggregate (ms):amber:40,86,112,120,180" >}}

- `Seq Scan` is stable for all queries, which makes sense because the same data is required.
- `HashAggregate` are different because of the choice of data processing
- `composite` is the fastest
- `json` is faster than `jsonb`
- `array` is faster than `object`

I thought that JSONB was faster than JSON, but I now understand it is faster for things like filtering data. But in this case, I pay for encoding in the first place, and there is no gain to expect. Only when the source column is JSONB encoded, there is no cost for encoding: it is paid on write.

Array being faster than objects make sense: there is less structure, the data is easier to create. I think there are places where each kind can be useful.

I wasn't sure if Postgres output type (binary or not) would impact the results, but after a quick benchmarks it looks like not.

## Server side

The previous part shows that `composite` is the fastest to execute on the database. But what really matters is the moment when the data is ready to use in the host language. There are two main use cases:
- **Host processing:** Once the data is ready, I need to apply an algorithm to it: I have a function that can compute the precise pricing for a stay, and then I filter by a maximum price.
- **JSON output:** The data does not need processing, it is sent back to a client in JSON shape

So each use case may have a unique best solution.

For this experiment, I use Python with `psycopg`, which is a Postgres driver for Python that supports low level configurations. One configuration is `text` versus `binary` output, and applies to each query.

### Python processing

I need to fetch the data and expose it in meaningful Python types. The expected format looks like: `list[tuple[str, list[tuple[date, Decimal]]]]`

```py
[
	(
		"ab18fc69-2f7d-4331-a9d2-615a7957a143",
		[
			(date(2025, 9, 28), Decimal("200.50")),
			...
		],
	)
]
```

This format may give a boost to `composite binary`, because the driver converts the binary in this exact format. Otherwise I need to manually convert the data. I use the `array` version of all `json` over `object`, because object are costlier the create and read.

I use pytest and pytest-benchmark to write the benchmark. Here is a sample of the code I have to write, but the full file is available at the end.

```py
def load_any_json_array_json(
    conn: Connection, query: bytes, *, binary: bool
) -> JSONOut:
    with conn.cursor() as cursor:
        cursor.execute(query, binary=binary)
        rows = cursor.fetchall()

    return [
        (
            row[0],
            [{"date": item[0], "price": item[1]} for item in row[1]],
        )
        for row in rows
    ]

#...

@pytest.mark.benchmark(group="json out")
class TestJSONOut:
    @pytest.mark.parametrize("binary", [False, True])
    @pytest.mark.parametrize(
        "expr",
        [JSON_OBJECT_EXPR, JSONB_OBJECT_EXPR],
        ids=["json object", "jsonb object"],
    )
    def test_json_object(
        self,
        conn: Connection,
        benchmark: BenchmarkFixture,
        binary: bool,
        expr: str,
    ):
        benchmark(
            load_any_json_object_json, conn, BASE_QUERY.format(expr), binary=binary
        )
```

{{< perf-chart title="Python Processing Performance" labels="composite binary,json array text,json array binary,jsonb array binary,jsonb array text,composite text" datasets="PostgreSQL (ms):blue:80,120,120,150,150,80|Python (ms):amber:140,110,110,110,120,230" >}}

- JSON parsing seems stable across all runs
- Composite binary seems a little slower, but not by much
- Composite text is much slower

Composite is not much faster, which can be odd. If `psycopg` uses pure python for data transformation, doing it by hand is not slower: the [NumericLoader](https://github.com/psycopg/psycopg/blob/c9e013d4441d9c9ae5bed61ce8fa561dcb0b9dae/psycopg_c/psycopg_c/types/numeric.pyx#L440) implementation uses optimised Python, but relies on the `Decimal` constructor. The speed on the database makes it the best choice still.

Composite text is very slow. Even tuples need to be parsed manually. I don't get why JSON isn't as slow: it needs to be parsed as array too. The [CompositeLoader](https://github.com/psycopg/psycopg/blob/c9e013d4441d9c9ae5bed61ce8fa561dcb0b9dae/psycopg/psycopg/types/composite.py#L243) is pure Python, while Python's own JSON is certainly optimised C.

### JSON API

I have to fetch the data and format it as JSON. I'm not pushing it to the point i keep it as strings, but it might be the better answer. I'm only interesting in aggregations, so I only format the sub list. The format looks like: `list[tuple[str, list[dict[str, str]]]]`

```py
[
    (
        "ab18fc69-2f7d-4331-a9d2-615a7957a143",
        [
	        {"date": "2025-09-28", "price": "200.50"}
	    ],
    )
]
```

This time, I use JSON objects, as this is the shape of the data transmitted. It should give a boost to all JSON queries, while composite still requires processing.

{{< perf-chart title="JSON API Performance" labels="json object binary,json object text,jsonb object binary,composite text,jsonb object text,composite binary" datasets="PostgreSQL (ms):blue:160,160,220,80,220,80|Python (ms):amber:60,70,50,200,60,200" >}}

- All `json` processing look the same
- `composite` in much slower in Python, regardless of binary or text

All JSON outputs are ready for output, so they require the less work on the Python side.

`composite binary` is definitely slower: `psycopg` pays for the conversion in Python `date` and `Decimal`, and then again for converting it back manually.

I don't really know why `composite text` is that slow in both benchmarks.

## Resources

- [Benchmarking script](test.py)
- [Postgres JSON functions](https://www.postgresql.org/docs/current/functions-json.html)
- [Postgres aggregation functions](https://www.postgresql.org/docs/current/functions-aggregate.html)
- [Psycopg](https://www.psycopg.org/)
