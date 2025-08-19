---
title: Overview & Motivation
nav_order: 2
permalink: /overview
---

## ⚡ Why materialized views? Real numbers

On a \~50k-row dataset, reading from pre-aggregated materialized views turns heavy joins into **double-digit to triple-digit speedups** compared to running the raw SQL each time.

### All features are designed to be **production-ready** with following principles

- **High availability**: MVs are created and refreshed in the background, ensuring minimal downtime.
- **Repeatable operations**: Clear APIs and CLI tasks for consistent behavior.
- **Observability**: Track runs, errors, and performance metrics.
- **Rails-native**: Integrates seamlessly with Active Job, Rails logger, and error handling.
- **Extensible**: Supports multiple job adapters (ActiveJob, Sidekiq, Resque) and can be customized for specific needs.
- **Security**: Contributions to security are encouraged, with a dedicated policy for reporting vulnerabilities.
- **Community-driven**: Contributions are welcome, with a CLA to ensure legal clarity.
- **All features are free and open source** under the MIT license. There is no other version or paid tier.

### Sample run (5 iterations)

With 50,000 rows

| view                    | iterations | baseline(ms) min\|avg\|max | mv(ms) min\|avg\|max | speedup_avg |
| ----------------------- | ---------: | -------------------------: | -------------------: | ----------: |
| mv_user_accounts        |          5 |             16 \| 31 \| 74 |          1 \| 2 \| 5 |        15.5 |
| mv_user_accounts_events |          5 |            70 \| 78 \| 108 |          1 \| 1 \| 2 |        78.0 |
| mv_user_activity        |          5 |          159 \| 161 \| 165 |          1 \| 1 \| 2 |       161.0 |
| mv_user                 |          5 |                1 \| 1 \| 2 |          1 \| 2 \| 7 |         0.5 |

### Stability check (100 iterations)

With 50,000 rows

| view                    | iterations | baseline(ms) min\|avg\|max | mv(ms) min\|avg\|max | speedup_avg |
| ----------------------- | ---------: | -------------------------: | -------------------: | ----------: |
| mv_user_accounts        |        100 |             15 \| 17 \| 69 |         1 \| 1 \| 20 |        17.0 |
| mv_user_accounts_events |        100 |             70 \| 70 \| 73 |          1 \| 1 \| 3 |        70.0 |
| mv_user_activity        |        100 |          158 \| 161 \| 242 |          1 \| 1 \| 2 |       161.0 |
| mv_user                 |        100 |                1 \| 1 \| 1 |          1 \| 1 \| 2 |         0.5 |

### Takeaways

- Multi-table aggregates shine: **\~70×** (accounts+events), **\~161×** (full activity).
- Single-table scans: little/no benefit; use normal indexes or caching.
- Materialize **expensive joins/aggregations** you read often.
- PostgreSQL
  - Materialized views (MVs) make it **faster** for complex queries, especially those involving expensive joins or aggregations.
  - MVs are **not** a silver bullet for all queries; use them when they fit the use case.
  - If you have a slow query with poor performance, MVs might help you speed it up significantly.
  - MVs are not a replacement for proper indexing and query optimization.
  - Read more about [PostgreSQL materialized views](https://www.postgresql.org/docs/current/rules-materializedviews.html).
