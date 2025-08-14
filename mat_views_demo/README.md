# mat_views_demo (demo app)

[![CI](https://img.shields.io/github/actions/workflow/status/your-org/rails_materialized_views/ci.yml?style=flat-square&label=Demo%20CI)](https://github.com/your-org/rails_materialized_views/actions)
![Not Shipped](https://img.shields.io/badge/shipping-NOT%20IN%20GEM-informational?style=flat-square)
![License](https://img.shields.io/badge/license-MIT-blue.svg?style=flat-square)

A standalone Rails app adjacent to the engine, used for **documentation, seeds, and benchmarks**. It is **not shipped** with the gem.

---

## Flow (diagram)

```mermaid
flowchart LR
  S[Seed demo data] --> D[Define demo views]
  D --> C[Create MVs]
  C --> U[Unique indexes]
  U --> R[Refresh]
  R --> V[Validate & Export CSV]
```

---

## Setup

```bash
bundle install
bin/rails db:create db:migrate

# Gemfile
# gem 'mat_views', path: '../mat_views'
```

Optional dev settings:

```ruby
# config/environments/development.rb
config.logger = ActiveSupport::Logger.new($stdout)
config.active_job.queue_adapter = :inline
```

---

## Commands

### Bootstrap (seed → define → create → index → refresh)

```bash
bundle exec rake mat_views:bootstrap_demo[1]
```

### Validate (baseline vs MV → CSV)

```bash
bundle exec rake mat_views:validate_demo\[5]
bundle exec rake mat_views:validate_demo\[100]
# CSV at tmp/mv_validate/<timestamp>/report.csv
```

### Create/refresh/delete via engine tasks

```bash
bundle exec rake mat_views:create_all\[true,--yes]
bundle exec rake mat_views:refresh_all\[estimated,--yes]
bundle exec rake mat_views:delete_all\[false,--yes]
```

---

## Enqueue adapter

```ruby
MatViews::Jobs::Adapter.enqueue(job_class, queue: MatViews.configuration.job_queue, args: [...])
```

* The adapter **does not guess**; configure **ActiveJob**, **Sidekiq**, or **Resque** in the demo app.
* Ensure your queue is running (unless using `:inline`).

---

## Docs & policies

* Engine README: [../mat\_views/README.md](../mat_views/README.md)
* Root README: [../README.md](../README.md)
* **Contributing:** [../CONTRIBUTING.md](../CONTRIBUTING.md)
* **Security policy:** [../SECURITY.md](../SECURITY.md)
* **Code of Conduct:** [../CODE\_OF\_CONDUCT.md](../CODE_OF_CONDUCT.md)