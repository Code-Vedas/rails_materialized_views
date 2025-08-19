# rails_materialized_views (mat_views)

[![Gem](https://img.shields.io/gem/v/mat_views.svg?style=flat-square)](https://rubygems.org/gems/mat_views)
[![CI](https://github.com/Code-Vedas/rails_materialized_views/actions/workflows/ci.yml/badge.svg)](https://github.com/Code-Vedas/rails_materialized_views/actions/workflows/ci.yml)
![License](https://img.shields.io/badge/license-MIT-blue.svg?style=flat-square)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-12%2B-336791?style=flat-square&logo=postgresql&logoColor=white)

> A Rails engine to define, create, refresh, and delete **PostgreSQL materialized views** with clean APIs, background jobs, observability, and CLI tasks. Built for **high availability** and **repeatable ops**.

- 📦 Engine/gem: [`mat_views/`](./mat_views)
- 🧪 Demo app: [`mat_views_demo/`](./mat_views_demo) _(not shipped with the gem)_

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

---

## Features

- **DB definitions**: SQL, strategy, unique index columns, dependencies
- **Create / Refresh / Delete** services & jobs (uniform responses)
- **Refresh strategies**: `regular`, `concurrent` (needs unique index), `swap`
- **CLI**: Rake tasks for create/refresh/delete by name, id, or all (with confirm)
- **Observability**: run tracking tables for create/refresh/delete
- **Rails-native**: Active Job, `Rails.logger`, clear error reporting

---

## Install (engine)

```ruby
# Gemfile
gem 'mat_views'
```

```bash
bundle install
bin/rails g mat_views:install
bin/rails db:migrate
```

Init:

```ruby
# config/initializers/mat_views.rb
MatViews.configure do |c|
  c.job_queue = :default # default queue for background jobs
  c.job_adapter = :active_job # (default), :sidekiq, :resque
end
```

---

## Job adapter (enqueue)

All enqueues go through the adapter — it **does not guess** backends; it uses what **you** configured:

```ruby
MatViews::Jobs::Adapter.enqueue(
  MatViews::RefreshViewJob,
  queue: MatViews.configuration.job_queue,
  args:  [definition_id, :estimated]
)
```

- Supported backends: **ActiveJob**, **Sidekiq**, **Resque** (more welcome).
- Configure your backend as usual; the adapter delegates accordingly.

---

## CLI (Rake tasks)

```bash
# Create
bundle exec rake mat_views:create_by_name\[VIEW_NAME,force,--yes]
bundle exec rake mat_views:create_by_id\[ID,force,--yes]
bundle exec rake mat_views:create_all\[force,--yes]

# Refresh
bundle exec rake mat_views:refresh_by_name\[VIEW_NAME,row_count_strategy,--yes]
bundle exec rake mat_views:refresh_by_id\[ID,row_count_strategy,--yes]
bundle exec rake mat_views:refresh_all\[row_count_strategy,--yes]

# Delete
bundle exec rake mat_views:delete_by_name\[VIEW_NAME,cascade,--yes]
bundle exec rake mat_views:delete_by_id\[ID,cascade,--yes]
bundle exec rake mat_views:delete_all\[cascade,--yes]
```

---

## Demo app

See [`mat_views_demo/`](./mat_views_demo) for seeds, MV definitions, and reproducible benchmarks (not shipped with the gem).

---

## Contributing, Security, Conduct

- **Contributing:** see [CONTRIBUTING.md](./CONTRIBUTING.md)
- **Security policy:** see [SECURITY.md](./SECURITY.md)
- **Code of Conduct:** see [CODE_OF_CONDUCT.md](./CODE_OF_CONDUCT.md)

---

## Professional support

Need help with Rails Materialized Views? We offer professional support and custom development services. Contact us at [sales@codevedas.com](mailto:sales@codevedas.com) for inquiries.

## License

MIT © Codevedas Inc.
