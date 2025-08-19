---
title: Installation & Setup
nav_order: 3
permalink: /install
---

This page explains how to install the `mat_views` gem, configure it, and use the CLI tasks for managing materialized views in your Rails application.

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

## Initializer

`bin/rails g mat_views:install` creates an initializer file at `config/initializers/mat_views.rb` and migrations for the run tracking tables and the materialized views definitions table.

```ruby
# config/initializers/mat_views.rb
MatViews.configure do |c|
  # you can set different name, make sure job queue is set to the same as in your job adapter
  # otherwise no views will be created/updated/deleted
  c.job_queue = :default # default queue for background jobs

  # must match your job adapter setup
  c.job_adapter = :active_job # (default), :sidekiq, :resque
end
```
