---
title: ""
draft: true
date:
lastmod:
description: ""
categories:
  - PostgreSQL
---

I often need to return several sub-rows for each top-level row of a given query - I will provide a case study later. This does not fit the regular SQL model, but PostgreSQL has powerful constructs and operations to help us build such queries. This post's goal is to compare several approaches, both in term of ease of use and performance. Performance is different here than in regular benchmarks, because it will span from the database to the host programming language: Python. More concretely, here are hypothesis I want to test:

1. Postgres composite types array offer better raw time performance that json objects array
2. Postgres composite types array offer better data compression performance that json objects array
3. Postgres composite types array offer better performance up to the host language
    - Conversion between JSON output from postgres result to python objects should be slower that using composite types
4. Postgres jsonb functions offer better performances than json functions

## Data model and setup

As usual, we'll try to solve some real world problem with a certain data model. Data size will be tweaked to a realistic but challenging size, also to ease benchmarks.

## Aggregation row results

The first estimates show 48ms for composite, 58ms for json array and 68ms for jsonb array. It kind of make sense, jsonb is finally costlier and only used when processing the data.

To better understand the differences in performance, I want to compare the explain plans that should look very similar. They are indeed composed of the same 4 steps, and only the duration of the last step is changed by the kind of aggregation.

| Method          | Parallel Seq Scan | Sort    | Gather Merge | GroupAggregate |
| --------------- | ----------------- | ------- | ------------ | -------------- |
| composite array | 13.7 ms           | 1.02 ms | 5.68 ms      | 4.26 ms        |
| json array      | 13.4 ms           | 1.03 ms | 3.38 ms      | 13.6 ms        |
| jsonb array     | 13.6 ms           | 1.05 ms | 3.51 ms      | 23.1 ms        |

These results seem in line with my expectations, after updating my ideas on JSONB: this binary format is efficient for storage efficiency and querying the data, but at the cost of encoding and decoding speed. In our case, the output is raw text, so we pay the encoding in JSONB by postgres, and certainly the decoding back by the server or our client.

## Python gathering

The python part seem to be low, pure json is still the best. Binary composites are ok.
