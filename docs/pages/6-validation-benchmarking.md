---
title: Validation & Benchmarking
nav_order: 6
permalink: /validation
---

# Validation & Benchmarking

This guide shows how we **verify correctness** (materialized view rows match the baseline SQL) and **measure performance** (baseline vs. MV reads) using the companion demo app **`mat_views_demo`**.

It uses two sets of tasks:

- **Demo data & views** (seed, define, create/index, refresh)
- **Validation** (timing and reporting)

Everything logs via `Rails.logger` and produces a CSV report suitable for docs and dashboards.

---

## Prerequisites

1. **Project layout (adjacent repos)**

   ```bash
   rails_materialized_views/
     mat_views/         # the engine
     mat_views_demo/    # the demo app (docs/examples live here)
   ```

2. **Demo app configured** with a working Postgres connection.

3. **Queue backend** (optional for this guide) if you plan to run create/refresh via jobs. The demo bootstrap uses the engine’s rake tasks which enqueue via:

   ```ruby
   MatViews::Jobs::Adapter.enqueue(job_class, queue: MatViews.configuration.job_queue, args: [...])
   ```

   The adapter assumes your backend is configured (ActiveJob, Sidekiq, Resque).

---

## 1) Demo data & views (one-shot bootstrap)

From the **`mat_views_demo/`** directory:

```bash
# Seed ~500 users (× scale), define 4 MV definitions,
# create them, add unique indexes, and do an initial refresh.
bin/rake 'mat_views:bootstrap_demo[1,--yes]'
```

What it does:

- **Seed** users, accounts, events, sessions (batched `insert_all`)
  - Resets PK sequences
  - Adds helpful base indexes (`events.occurred_at`, `sessions.started_at`, `accounts.plan`)

- **Define** four MV definitions _(idempotent)_:
  - `mv_users` (1 table)
  - `mv_user_accounts` (2 tables)
  - `mv_user_accounts_events` (3 tables)
  - `mv_user_activity` (4 tables)

- **Create** all MVs via engine tasks (skip confirm)
- **Ensure unique indexes** on each MV (required for concurrent refresh)
- **Refresh** all MVs (default `:estimated` row count)

{: .note}

> Prefer the bootstrap for a clean slate. If you want the steps separately:

```bash
bin/rake 'mat_views:seed_demo[1,--yes]'
bin/rake mat_views:define_demo_views
bin/rake 'mat_views:create_all[,--yes]'
bin/rake 'mat_views:refresh_all[,--yes]'
```

### Notes

- `mat_views:seed_demo[scale,--yes]` accepts `scale` (integer) and a confirmation skip flag (`--yes` or `YES=1`).
- All actions write progress via `Rails.logger` (not `puts`). Make sure your dev logger outputs to STDOUT.

---

## 2) Validate & benchmark

From **`mat_views_demo/`**:

```bash
# Run the validator for N iterations per view (default: 5)
bin/rake 'mat_views:validate_demo[100]'

# or with an env var:
ITER=100 bin/rake mat_views:validate_demo
```

### What the validator does

- Discovers existing materialized views from `pg_matviews`
  _(excluding system schemas)_.
- Matches them to `MatViews::MatViewDefinition` records (to fetch the baseline SQL).
- For each definition present as a physical MV:
  - Runs the **baseline** SQL (the definition’s `SELECT`) `iterations` times and records per-iteration duration.
  - Runs the **MV read** (a `SELECT` from the MV) `iterations` times and records per-iteration duration.
  - Captures **row counts** from both paths (simple correctness check).

- Writes a CSV to:

  ```bash
  tmp/mv_validate/<UTC timestamp>/report.csv
  ```

- Logs a per-view summary, e.g.:

  ```bash
  [validate_demo] mv_user_activity: baseline_avg=161ms, mv_avg=1ms, speedup≈161.0x
  ```

### CSV Schema

Header:

```bash
view,iterations,
baseline_avg_ms,baseline_min_ms,baseline_max_ms,
mv_avg_ms,mv_min_ms,mv_max_ms,
speedup_avg,
rows_baseline,rows_mv
```

- **speedup_avg** = `baseline_avg_ms / mv_avg_ms` (higher is better)
- Rows are computed by the validator (counts from each path).

### Where the numbers come from

- Timing uses a monotonic clock in `MatViewsDemo::Validator`.
- No “warmup” by default (we measure cold/hot mixed reality). If you prefer warm cache, run the task twice and use the second run, or extend the validator with a warmup loop.

---

## Example results (for docs)

### Quick smoke (5 iterations)

| view                    | iterations | baseline_avg_ms | baseline_min_ms | baseline_max_ms | mv_avg_ms | mv_min_ms | mv_max_ms | speedup_avg | rows_baseline | rows_mv |
| ----------------------- | ---------: | --------------: | --------------: | --------------: | --------: | --------: | --------: | ----------: | ------------: | ------: |
| mv_user_accounts        |          5 |              31 |              16 |              74 |         2 |         1 |         5 |        15.5 |         50000 |   50000 |
| mv_user_accounts_events |          5 |              78 |              70 |             108 |         1 |         1 |         2 |        78.0 |         50000 |   50000 |
| mv_user_activity        |          5 |             161 |             159 |             165 |         1 |         1 |         2 |       161.0 |         50000 |   50000 |
| mv_users                |          5 |               1 |               1 |               2 |         2 |         1 |         7 |         0.5 |         50000 |   50000 |

### Stable averages (100 iterations)

| view                    | iterations | baseline_avg_ms | baseline_min_ms | baseline_max_ms | mv_avg_ms | mv_min_ms | mv_max_ms | speedup_avg | rows_baseline | rows_mv |
| ----------------------- | ---------: | --------------: | --------------: | --------------: | --------: | --------: | --------: | ----------: | ------------: | ------: |
| mv_user_accounts        |        100 |              17 |              15 |              69 |         1 |         1 |        20 |        17.0 |         50000 |   50000 |
| mv_user_accounts_events |        100 |              70 |              70 |              73 |         1 |         1 |         3 |        70.0 |         50000 |   50000 |
| mv_user_activity        |        100 |             161 |             158 |             242 |         1 |         1 |         2 |       161.0 |         50000 |   50000 |
| mv_users                |        100 |               1 |               1 |               1 |         1 |         1 |         2 |         1.0 |         50000 |   50000 |

{: .note}

> These numbers are illustrative from the demo dataset. Expect different absolute values in your environment, but the **relative** gains on multi-join aggregates tend to be dramatic (10×–160×+).

---

## Correctness checks

- The validator compares **row counts** between the baseline and MV read.
- For tighter guarantees, you can extend `MatViewsDemo::Validator` to:
  - Compare **aggregates** (e.g., `SUM`/`COUNT DISTINCT`)
  - Sample keys and compare **row contents**
  - Do a full **set diff** in staging (expensive!)

---

## Tips for reliable benchmarks

- Use a **quiet database** (limit other load).
- Keep **autovacuum/ANALYZE** on (statistics matter).
- Run **more iterations** (e.g., 100 or 300) for tighter min/max bands.
- Consider **one warmup pass** if you want to measure hot-cache behavior.
- Document environment: Postgres version, hardware, shared buffers, etc.

---

## Troubleshooting

- **“No materialized views found”**
  Run the bootstrap or create views. The validator discovers views from `pg_matviews`.

- **“Found MVs in DB, but no matching MatViewDefinition records”**
  The validator needs the **definition** to fetch the baseline SQL. Ensure your `MatViewDefinition` records match the MV names.

- **Row counts don’t match**
  Your MV SQL may have drifted from the baseline SQL. Recreate/swap the MV with the current definition, or debug differences (filters/joins/grouping).

- **Variance is high**
  Increase iterations; ensure low background load; check for big autovacuum runs or long transactions.

---

## Artifacts & docs integration

- CSV lives under `tmp/mv_validate/<timestamp>/report.csv` (demo app).
- Paste rendered Markdown tables into:
  - Root `README.md` → **Why materialized views? Real numbers**
  - `docs/validation/` → per-run archives, if you keep historical results

You can also drop the CSV into `/docs/validation/` and link it from the docs site.

---

## What’s included in the demo views

We ship 4 definitions to represent increasing complexity:

1. **`mv_users`** - single table projection
2. **`mv_user_accounts`** - two-table aggregate join
3. **`mv_user_accounts_events`** - three-table aggregate join
4. **`mv_user_activity`** - four-table aggregate join

All are configured for **concurrent** refresh with appropriate **unique indexes** on the result key (`id` or `user_id`).
