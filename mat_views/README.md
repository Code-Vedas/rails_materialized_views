# MatViews

A mountable Rails engine to define, manage, and monitor PostgreSQL materialized views.

## Installation

Add this line to your application's Gemfile:

```ruby
gem "mat_views", path: "path/to/mat_views"
```

Then execute:

```bash
bundle install
rails generate mat_views:install
``` 

## Roadmap
- MVP: CLI + models + rake tasks
- v1: Admin UI
- v2: Resilience, retries
- v3: Plugin API and analytics