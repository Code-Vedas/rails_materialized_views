# frozen_string_literal: true

# This migration creates the mat_view_definitions table, which stores definitions for materialized views.
# It includes fields for the view name, SQL definition, refresh strategy, schedule, unique index columns,
# dependencies, last refreshed timestamp, and timestamps for creation and updates.
class CreateMatViewDefinitions < ActiveRecord::Migration[7.0]
  def change
    create_table :mat_view_definitions do |t|
      t.string :name, null: false
      t.text :sql, null: false
      t.string :refresh_strategy, default: 'manual'
      t.string :schedule_cron
      t.jsonb :unique_index_columns, default: []
      t.jsonb :dependencies, default: []
      t.datetime :last_refreshed_at
      t.timestamps
    end
  end
end
