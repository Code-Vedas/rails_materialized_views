---
layout: default
title: Home
nav_order: 1
---

# rails_materialized_views (mat_views)

[![Gem](https://img.shields.io/gem/v/mat_views.svg?style=flat-square)](https://rubygems.org/gems/mat_views)
[![CI](https://github.com/Code-Vedas/rails_materialized_views/actions/workflows/ci.yml/badge.svg)](https://github.com/Code-Vedas/rails_materialized_views/actions/workflows/ci.yml)
![License](https://img.shields.io/badge/license-MIT-blue.svg?style=flat-square)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-12%2B-336791?style=flat-square&logo=postgresql&logoColor=white)

> A Rails engine to define, create, refresh, and delete **PostgreSQL materialized views** with clean APIs, background jobs, observability, and CLI tasks. Built for **high availability** and **repeatable ops**.

- 📦 Engine/gem: [`mat_views/`](https://github.com/Code-Vedas/rails_materialized_views/tree/main/mat_views)
- 🧪 Demo app: [`mat_views_demo/`](https://github.com/Code-Vedas/rails_materialized_views/tree/main/mat_views_demo) *(not shipped with the gem)*

---

## Install (engine)

```ruby
# Gemfile
gem 'mat_views'
```

```bash
# Install the gem
bundle install

# Generate the initializer and migrations
bin/rails g mat_views:install

# Run the migrations
bin/rails db:migrate
```

## Links

* [Installation & Setup](./install) for how to install the `mat_views` gem, configure it, and use the CLI tasks for managing materialized views in your Rails application.
* [Usage & Examples](./usage) section for detailed guides on defining, creating, refreshing, and deleting materialized views using the `mat_views` gem.
* [Engine](./engine) section for an overview of the engine's structure, configuration, and how it integrates with your Rails application.
* [Validation & Benchmarking](./validation) for how to validate your materialized views and benchmark their performance.
* [PostgreSQL MV Best Practices](./pg-best-practices) for practical, production-oriented advice on managing materialized views in PostgreSQL.
* [FAQ / Troubleshooting](./faq) for answers to common questions and troubleshooting tips when working with the `mat_views` gem and PostgreSQL materialized views.

## Features

* **DB definitions**: SQL, strategy, unique index columns, dependencies
* **Create / Refresh / Delete** services & jobs (uniform responses)
* **Refresh strategies**: `regular`, `concurrent` (needs unique index), `swap`
* **CLI**: Rake tasks for create/refresh/delete by name, id, or all (with confirm)
* **Observability**: run tracking tables for create/refresh/delete
* **Rails-native**: Active Job, `Rails.logger`, clear error reporting

---

## Planned features

* **Scheduling**: periodic refreshes via cron or background jobs
* **UI**: dashboard for definitions, runs, errors, and manual operations
* **Notifications**: alerts for failures, performance metrics
* **More job adapters**: support for additional background job systems
* **Definition lifecycle**: refresh or delete on definition changes
* **Any Ideas?** [Open an issue or PR on GitHub!](https://github.com/Code-Vedas/rails_materialized_views/issues/new/choose)


## Professional support
Need help with Rails Materialized Views? We offer professional support and custom development services. Contact us at [sales@codevedas.com](mailto:sales@codevedas.com) for inquiries.

## License

MIT © Codevedas Inc.