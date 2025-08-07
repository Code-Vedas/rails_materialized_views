# frozen_string_literal: true

# This migration creates the mat_view_refresh_runs table,
# which stores information about refresh runs for materialized views.
# It includes fields for the associated mat_view_definition, status, timestamps for start and finish,
# duration in milliseconds, row count, error messages, and additional metadata.
class CreateMatViewRefreshRuns < ActiveRecord::Migration[7.0]
  def change
    create_table :mat_view_refresh_runs do |t|
      t.references :mat_view_definition, null: false, foreign_key: true
      t.string :status
      t.datetime :started_at
      t.datetime :finished_at
      t.integer :duration_ms
      t.integer :rows_count
      t.text :error
      t.jsonb :meta, default: {}
      t.timestamps
    end
  end
end
