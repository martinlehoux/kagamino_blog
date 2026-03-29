---
title: "Managing analytical workloads in startups"
draft: true
description: ""
categories:
  - PostgreSQL
---

## Current issues

- Issues with querying large dataset in online postgres (90GB)
- The dataset is analytics events and some business models.
- Often used for AB testing purpose, for instance measuring conversion rates grouped by some experiment values.
- We a have a readonly database, the queries are slow

## Hypothesis/Solutions

- Writing better queries: this also needs to be maintainable (e.g. we add more and more queries, it should not need to be carefully handcrafted)
- Using another engine
  - Postgres like but OLAP oriented
  - Pure OLAP (Clockhouse, Duckdb)
  - AWS for simplicity (Athena or Redshift Spectrum)
  - Scripts on parquet files: maximum adaptability
- How to get the data?
  - it seems that it is already parquets
  - it looks too slow to download all the data periodically: process in the cloud or incremental sync
- Parquet:
  - possible to cluster by event? by datetime?
  - sounds like recreating bigquery

## Exporting cloud data

- In AWS RDS snapshot, we can export only part of the data. In our case, we can start by `greengobackend.public.core_experimentationanalyticsevent`
- The whole database size is supposed to be 390GB, with 65GB of `core_experimentationanalyticsevent`
- The exported folder in S3 is only 3.8GB of parquet files, impressive
- There are 20M events in the database

## DuckDB

- We may try later to query from s3, for now simply download it
- `aws s3 sync s3://bi-data-test-gg/export-experimentationanalyticsevent experimentationanalyticsevent`
- As always when I use this type of tool, it ate my RAM and my desktop crashed
- It looks like it's not the easiest on my machine to create table from parquet files
  Let's try a simple summary request to compare potential performances

```sql
with growthbook_experimentationanalyticsevent as (
select
  sent_at AS timestamp,
  device_information ->> 'greengo_device_id' AS device_id,
  event ->> 'customEventID' AS custom_event_id
from 'experimentationanalyticsevent/greengobackend/public.core_experimentationanalyticsevent/1/*.gz.parquet'
)
select custom_event_id, count(*) from growthbook_experimentationanalyticsevent group by custom_event_id;
```

I will then run the same query on my Big production postgres, and also on my readonly replica (smaller). It doesn't use more than 600MB on duckdb.

| Context             | Duration |
| ------------------- | -------- |
| Duckdb              | 10.1s    |
| Duckdb 16GB         | 10.0s    |
| Postgres production | 180s     |
| Postgres readonly   |          |

## Analytical workload

Then I'd like to run a real workload : an AB test experiment result.
It requires only a few language tweaks and type cast.
The result is slower than I expected (49.5s), but the same query on production did not complete in several minutes.

The query ran directly on the parquet file: let's try to create a physical backed table within duckdb to see if it improves overall latency. `CREATE TABLE growthbook_experimentationanalyticsevent AS SELECT * FROM 'file.gz.parquet'`
I get some conversion error while trying to create a table from the query.
Creating the table takes more than 20GB of RAM, not easy on my system.
The table is 50GB large. I expect queries to run faster du to less compression.

> The memory_limit setting controls how much data DuckDB is allowed to keep in memory. By default, this is set to 80% of the physical RAM of your system (e.g., if your system has 16 GB RAM, this defaults to 12.8 GB). The memory limit can be changed using the following command: `SET memory_limit = '4GB';`

Weirdly, it is slower when reading from the materialized table.

We can try to go once step further, and materializing the CTE in a parquet file. `COPY (SELECT * FROM 'file.gz.parquet') TO 'file-2.gz.parquet' (FORMAT parquet)`. Desktop died once again, I will now limit memory to 16GB (and run again some of the benchmarks).

I don't understand, I can select the CTE, but when I materialize it I have a format error. I'll use [TRY_CAST](https://duckdb.org/docs/stable/sql/expressions/cast.html#try_cast) instead of CAST.

First I exported the CTE to a compressed parquet: it took >2m, it's 3.0GB large. Let's try to perform the query on it.

Then export the CTE to a physical duckdb: the previous db size was 50GB, it took 2m42, the database is now 82GB, so I expect 32GB of new data. Let's perform the query on it.

The results are shocking, I don't even have indices (ok maybe yuo don't do indices on OLAP databases).

Some insights taken from explain analyze:

- Table scan (20M rows) filtered into 14k rows takes 600ms (ok numbers don't add up)
- The same parquet scan (14k of 20M) takes 940ms. It's very fast.
- The multiple parquet scan take 80s, it's a bottleneck. The filtering seems to be done later.

| Context                                | Duration |
| -------------------------------------- | -------- |
| CTE from parquet                       | 49.5s    |
| CTE from physical table                | 1m22     |
| CTE materialized in compressed parquet | 600ms    |
| CTE materialized in physical table     | 300ms    |

The expected results for reference:

```
variation	dimension	users	main_sum	main_sum_squares	covariate_sum	covariate_sum_squares	main_covariate_sum_product
0	""	4647	603	603.0	10	10.0	3
__multiple__	""	1	0	0.0	0	0.0	0
1	""	4422	589	589.0	12	12.0	4
```

{{<details summary="Our sample analytics query for AB test experiment">}}

```sql
WITH growthbook_experimentationanalyticsevent AS (
    SELECT
        CAST(sent_at) AS timestamp,
        device_information ->> 'greengo_device_id' AS device_id,
        event ->> 'customEventID' AS custom_event_id,
        event ->> 'elementLabel' AS element_label,
        event ->> 'elementSecondaryLabel' AS element_secondary_label,
        -- Strings
        event -> 'value' -> 'experiment' ->> 'key' AS experiment_id,
        event ->> 'featureKey' AS feature_key,
        event ->> 'step' AS step,
        event ->> 'filterItem' AS filter_item,
        event ->> 'paymentType' AS payment_type,
        event -> 'tripSearchFormValues' ->> 'tripSearchMode' AS trip_search_mode_from_form_values,
        event -> 'hostingSearchParameters' ->> 'tripSearchMode' AS trip_search_mode_from_hosting_search_parameters,
        event ->> 'bookingMode' AS booking_mode,
        -- JSON
        event -> 'featureValue' AS feature_value,
        event -> 'value' AS _value,
        -- Cast
        CAST(event -> 'value' -> 'result' ->> 'variationId' AS int) AS variation_id,
        CAST(event ->> 'index' AS int) AS _index,
        CAST(event ->> 'isSelected' AS boolean) AS is_selected,
        CAST(event ->> 'isScrollable' AS boolean) AS is_scrollable,
        CAST(event ->> 'numberOfFullyVisibleFilters' AS int) AS number_of_fully_visible_filters,
        CAST(event ->> 'value' AS varchar) AS value_as_string,
        CAST(event ->> 'totalPrice' AS decimal) AS total_price,
        CAST(event ->> 'totalPricePaidAsMoney' AS decimal) AS total_price_paid_as_money
    FROM
        core_experimentationanalyticsevent
),
__rawExperiment AS (
    SELECT
        device_id,
        timestamp,
        experiment_id,
        variation_id
    FROM
        growthbook_experimentationanalyticsevent
    WHERE
        custom_event_id = 'CE0158'
        AND timestamp BETWEEN '2025-03-18 18:00:00' AND '2025-04-11 07:01:02'
),
__experimentExposures AS (
    -- Viewed Experiment
    SELECT
        e.device_id AS device_id,
        CAST(e.variation_id AS varchar) AS variation,
        e.timestamp AS timestamp
    FROM
        __rawExperiment e
    WHERE
        e.experiment_id = 'new-checkout-mobile-conversion-rate'
        AND e.timestamp >= '2025-03-18 18:00:00'
        AND e.timestamp <= '2025-04-11 07:01:02'
),
__experimentUnits AS (
    -- One row per user
    SELECT
        e.device_id AS device_id,
(
            CASE WHEN COUNT(DISTINCT e.variation) > 1 THEN
                '__multiple__'
            ELSE
                MAX(e.variation)
            END) AS variation,
        MIN(e.timestamp) AS first_exposure_timestamp
    FROM
        __experimentExposures e
    GROUP BY
        e.device_id
),
__distinctUsers AS (
    SELECT
        device_id,
        CAST('' AS varchar) AS dimension,
        variation,
        first_exposure_timestamp AS timestamp,
        DATE_TRUNC('day', first_exposure_timestamp) AS first_exposure_date,
        first_exposure_timestamp AS preexposure_end,
        first_exposure_timestamp - INTERVAL '336 hours' AS preexposure_start
    FROM
        __experimentUnits
),
__metric AS (
    -- Metric ([LEGACY] Booking Purchase)
    SELECT
        device_id AS device_id,
        1 AS value,
        m.timestamp AS timestamp
    FROM (
        SELECT
            timestamp,
            device_id,
            custom_event_id,
            element_label,
            element_secondary_label,
            feature_key,
            booking_mode,
            step,
            _index,
            is_selected,
            filter_item,
            payment_type,
            is_scrollable,
            number_of_fully_visible_filters,
            _value,
            value_as_string,
            trip_search_mode_from_form_values,
            trip_search_mode_from_hosting_search_parameters,
            total_price
        FROM
            growthbook_experimentationanalyticsevent
        WHERE
            timestamp BETWEEN '2025-03-04 18:00:00' AND '2025-04-11 07:01:02') m
    WHERE
        custom_event_id = 'CE0026'
        AND m.timestamp >= '2025-03-04 18:00:00'
        AND m.timestamp <= '2025-04-11 07:01:02'
),
__userMetricJoin AS (
    SELECT
        d.variation AS variation,
        d.dimension AS dimension,
        d.device_id AS device_id,
(
            CASE WHEN m.timestamp >= d.timestamp
                AND m.timestamp <= '2025-04-11 07:01:02' THEN
                m.value
            ELSE
                NULL
            END) AS value
FROM
    __distinctUsers d
    LEFT JOIN __metric m ON (m.device_id = d.device_id)
),
__userMetricAgg AS (
    -- Add in the aggregate metric value for each user
    SELECT
        umj.variation AS variation,
        umj.dimension AS dimension,
        umj.device_id,
        COALESCE(MAX(umj.value), 0) AS value
    FROM
        __userMetricJoin umj
    GROUP BY
        umj.variation,
        umj.dimension,
        umj.device_id
),
__userCovariateMetric AS (
    SELECT
        d.variation AS variation,
        d.dimension AS dimension,
        d.device_id AS device_id,
        COALESCE(MAX(value), 0) AS value
    FROM
        __distinctUsers d
        JOIN __metric m ON (m.device_id = d.device_id)
    WHERE
        m.timestamp >= d.preexposure_start
        AND m.timestamp < d.preexposure_end
    GROUP BY
        d.variation,
        d.dimension,
        d.device_id)
    -- One row per variation/dimension with aggregations
    SELECT
        m.variation AS variation,
        m.dimension AS dimension,
        COUNT(*) AS users,
    SUM(COALESCE(m.value, 0)) AS main_sum,
    SUM(POWER(COALESCE(m.value, 0), 2)) AS main_sum_squares,
    SUM(COALESCE(c.value, 0)) AS covariate_sum,
    SUM(POWER(COALESCE(c.value, 0), 2)) AS covariate_sum_squares,
    SUM(COALESCE(m.value, 0) * COALESCE(c.value, 0)) AS main_covariate_sum_product
FROM
    __userMetricAgg m
    LEFT JOIN __userCovariateMetric c ON (c.device_id = m.device_id)
GROUP BY
    m.variation,
    m.dimension
```

{{</details>}}

## Resources

- https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_ExportSnapshot.html
