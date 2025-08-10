# frozen_string_literal: true

# This migration creates the mat_view_definitions table, which stores definitions for materialized views.
# It includes fields for the view name, SQL definition, refresh strategy, schedule, unique index columns,
# dependencies, last refreshed timestamp, and timestamps for creation and updates.
class CreateMatViewDefinitions < ActiveRecord::Migration[7.1]
  def change
    create_table :mat_view_definitions do |t|
      t.string :name, null: false, comment: 'The name of the materialized view'
      t.text :sql, null: false, comment: 'The SQL query defining the materialized view'
      # refresh_strategy can be
      # regular: 0 - Default strategy, in-place refresh.
      # concurrent: 1 - Concurrent refresh, requires at least one unique index.
      # swap: 2 - Swap the materialized view with a new one, uses more memory.
      t.integer :refresh_strategy, default: 0, null: false,
                                   comment: 'Strategy for refreshing the materialized view. Options: regular, concurrent, swap'
      t.string :schedule_cron, comment: 'Cron schedule for automatic refresh of the materialized view'
      t.jsonb :unique_index_columns, default: [], comment: 'Columns used for unique indexing, if any'
      t.jsonb :dependencies, default: [],
                             comment: 'Dependencies of the materialized view, such as other views or tables'
      t.datetime :last_refreshed_at, comment: 'Timestamp of the last refresh operation'
      t.timestamps
    end
  end
end
