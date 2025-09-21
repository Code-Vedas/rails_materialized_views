---
title: PostgreSQL MV Best Practices
nav_order: 7
permalink: /pg-best-practices
---

# PostgreSQL MV Best Practices

Materialized views (MVs) are fantastic for speeding up heavy joins/aggregations, but they add operational responsibilities.
This guide distills practical, production-oriented advice tuned to how this project manages MVs (definitions → services → jobs → run tracking).

---

## 1) Model the definition well

- **Simple identifier names.** Keep `MatViews::MatViewDefinition.name` free of dots - e.g., `mv_user_activity`. Schema is resolved from `search_path` and safely quoted by services.
- **Explicit columns.** Avoid `SELECT *`. List the output columns; it stabilizes consumers and indexes.
- **Deterministic SQL.** Prefer immutable/stable functions. Avoid volatile ones (`random()`, `clock_timestamp()`), which break refresh determinism and diffability.
- **Shape for uniqueness.** If you want **concurrent** refresh, design a natural unique key in the result (e.g., `user_id` or a composite). You’ll create a **unique index** on that key.

---

## 2) Pick the right refresh strategy

| Strategy       | When to use                                                   | Pros                          | Cons                                           | Requirements                           |
| -------------- | ------------------------------------------------------------- | ----------------------------- | ---------------------------------------------- | -------------------------------------- |
| **Regular**    | Low traffic; brief read lock OK                               | Simple                        | Locks reads during refresh                     | none                                   |
| **Concurrent** | Reads must stay available                                     | No read lock                  | Slower; cannot run inside a transaction block  | **Unique index** covering all rows     |
| **Swap**       | Low downtime without unique key; complex rebuild choreography | Atomic content swap; flexible | Recreate indexes/privileges; more moving parts | Transactional swap & careful scripting |

### Guidelines

- If you can add a unique key, **concurrent** is often ideal.
- If you can’t, consider **swap** for near-zero read downtime.
- Use **regular** for simplicity when brief read locks are acceptable (internal/admin UIs, nightly batches).

---

## 3) Indexing the MV

- **Unique index** (for concurrent refresh):

  ```sql
  CREATE UNIQUE INDEX CONCURRENTLY IF NOT EXISTS idx_mv_user_activity_user_id
  ON "public"."mv_user_activity"(user_id);
  ```

- **Query-pattern indexes.** Add additional (non-unique) indexes to match your read queries: projections, predicates, join keys.
- **Create before first concurrent load.** Pattern:

  ```sql
  CREATE MATERIALIZED VIEW "public"."mv_user_activity" WITH NO DATA AS ... ;
  CREATE UNIQUE INDEX CONCURRENTLY ... ;
  REFRESH MATERIALIZED VIEW CONCURRENTLY "public"."mv_user_activity";
  ```

  This avoids one blocking load and ensures the first population keeps reads open.

{: .note}

> With **swap**, remember the new temp MV needs the **same indexes** before you swap names.

---

## 4) Locking & transaction gotchas

- `REFRESH MATERIALIZED VIEW CONCURRENTLY` **cannot run inside a transaction block** (same rule as `CREATE INDEX CONCURRENTLY`). Ensure your orchestration runs it outside a wrapping `BEGIN`.
- Regular refresh holds locks that **block readers**; schedule during off-peak or prefer concurrent/swap.
- Beware of **long transactions** or open cursors on the MV - they can stall refresh or index builds. Monitor `pg_stat_activity`.

---

## 5) Statistics, vacuum, and planner health

- MVs are physical relations. Keep planner stats fresh:
  - Large changes? `ANALYZE "schema"."mv_name"` after refresh (or rely on autovacuum).
  - Track bloat/visibility maps like any big table; indexes still need love over time.

- Estimated row counts (`reltuples`) power fast metrics. For verification, use exact counts selectively (`COUNT(*)`).

---

## 6) Scheduling & staleness windows

- Define a **freshness SLO** (e.g., “≤ 15 min stale”). Align your refresh cadence accordingly.
- Watch **duration trends** in run tables; scale hardware or strategy if refresh exceeds the SLO.
- Stagger heavy MVs to avoid load spikes; don’t refresh all at once if not necessary.

---

## 7) Security & access

- Grant least privilege:

  ```sql
  GRANT SELECT ON "public"."mv_user_activity" TO app_user;
  ```

- Treat MVs as **derived data** that may contain sensitive aggregates. Apply the same review you’d apply to tables exposed to applications.

---

## 8) Dependency management

- Capture upstreams in definition `dependencies` for visibility (“tables/views/MVs I read from”). It helps with ordering and documentation.
- If MVs depend on other MVs, define a **safe refresh order** or let independent jobs run with retries. Swap strategy can minimize cascading lock risks.

---

## 9) When _not_ to use an MV

- Single-row lookups or trivial filters that indexes can satisfy.
- Highly volatile data with **zero tolerance** for staleness (consider caching layers or streaming materialization instead).
- Write paths where you need transactional visibility of derived results (MVs update only on refresh).

---

## 10) Operational playbooks

### Creation (idempotent with NO DATA)

```sql
CREATE MATERIALIZED VIEW "public"."mv_x" WITH NO DATA AS
SELECT ... ;

-- Build required indexes (CONCURRENTLY where possible)
CREATE UNIQUE INDEX CONCURRENTLY IF NOT EXISTS idx_mv_x_key ON "public"."mv_x"(key);

-- First population (keeps reads available)
REFRESH MATERIALIZED VIEW CONCURRENTLY "public"."mv_x";
```

### Regular vs concurrent refresh

```sql
-- Regular (locks readers)
REFRESH MATERIALIZED VIEW "public"."mv_x";

-- Concurrent (requires unique index; not inside BEGIN)
REFRESH MATERIALIZED VIEW CONCURRENTLY "public"."mv_x";
```

### Swap (pattern)

```sql
-- 1) Build temp
CREATE MATERIALIZED VIEW "public"."mv_x__tmp_20250817" AS
SELECT ... ;

-- 2) Recreate indexes/privileges on temp
CREATE UNIQUE INDEX CONCURRENTLY idx_mv_x_tmp_key ON "public"."mv_x__tmp_20250817"(key);
GRANT SELECT ON "public"."mv_x__tmp_20250817" TO app_user;

-- 3) Transactional swap
BEGIN;
  ALTER MATERIALIZED VIEW "public"."mv_x" RENAME TO "mv_x__old_20250817";
  ALTER MATERIALIZED VIEW "public"."mv_x__tmp_20250817" RENAME TO "mv_x";
COMMIT;

-- 4) Cleanup old later (optional, outside critical path)
DROP MATERIALIZED VIEW IF EXISTS "public"."mv_x__old_20250817";
```

---

## 11) Monitoring & alerting

- Use the **run tables** to drive dashboards:
  - `duration_ms` over time; percentiles
  - last `status` per MV
  - `row_count_before` or `row_count_after` (if tracked) to catch anomalies

- Alert on:
  - consecutive **failures**
  - refresh time > SLO
  - **no successful refresh** within the freshness window

---

## 12) Partitioning & very large datasets

- MVs themselves aren’t partitioned. If source tables are partitioned, your MV still materializes the full result. For extreme sizes:
  - Consider **sharding the logic** across multiple MVs and `UNION ALL` a view on top.
  - Or move to a **swap** pattern that incrementally builds per-slice content and then unifies.

---

## 13) CI/CD integration

- Treat MVs as **generated artifacts**:
  - Keep **definitions** in code.
  - Use **Create/Refresh/Delete services** and **jobs** to manage lifecycle.
  - In releases, prefer **swap** or **concurrent** to reduce blast radius.

- Include **validation** in pre-prod: run the demo validator or your own on representative data.

---

## 14) Common pitfalls

- **Concurrent refresh without unique index**
  You’ll get: “cannot refresh materialized view concurrently without a unique index”.
- **Wrapping concurrent refresh in a transaction**
  Like `CREATE INDEX CONCURRENTLY`, it must be outside a transaction block.
- **`SELECT *` drift**
  Downstream code breaks when new columns appear. Be explicit.
- **Volatile SQL**
  Results differ across runs; tests and diffs become unreliable.

---

## 15) How this project helps

- **Definitions**: Single source of truth (name, SQL, strategy, metadata).
- **Services**: Safe quoting, validation, and strategy-specific execution.
- **Jobs & Adapter**: Uniform enqueue → run tables with timings/status/meta.
- **Rake tasks**: Admin-friendly CLI with confirmations and logging.
- **Demo & Validator**: Seed, build, refresh, and benchmark with reproducible scripts.
