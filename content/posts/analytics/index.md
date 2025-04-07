---
title: "Managing analytical workloads in startups"
draft: true
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

## Resources

- https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_ExportSnapshot.html
