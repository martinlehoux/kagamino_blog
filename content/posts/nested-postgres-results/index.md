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
**I should compare explain to see what blocks are impacted**

## Python gathering

The python part seem to be low, pure json is still the best. Binary composites are ok.
