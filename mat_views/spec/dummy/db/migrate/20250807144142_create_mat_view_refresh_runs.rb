# frozen_string_literal: true

# This migration creates the mat_view_refresh_runs table,
# which stores information about refresh runs for materialized views.
# It includes fields for the associated mat_view_definition, status, timestamps for start and finish,
# duration in milliseconds, row count, error messages, and additional metadata.
class CreateMatViewRefreshRuns < ActiveRecord::Migration[7.0]
  def change
    create_table :mat_view_refresh_runs do |t|
      t.references :mat_view_definition, null: false, foreign_key: true,
                                         comment: 'Reference to the materialized view definition being refreshed'
      # Status can be
      # pending: 0 - The refresh operation is queued but not yet started.
      # running: 1 - The refresh operation is currently in progress.
      # success: 2 - The refresh operation completed successfully.
      # failed: 3 - The refresh operation encountered an error.
      t.integer :status, default: 0, null: false,
                         comment: 'Status of the refresh run. Options: pending, running, success, failed'
      t.datetime :started_at, comment: 'Timestamp when the refresh operation started'
      t.datetime :finished_at, comment: 'Timestamp when the refresh operation finished'
      t.integer :duration_ms, comment: 'Duration of the refresh operation in milliseconds'
      t.integer :rows_count, comment: 'Number of rows in the materialized view after refresh'
      t.text :error, comment: 'Error message if the refresh operation failed'
      t.jsonb :meta, default: {}, comment: 'Additional metadata about the refresh run, such as job ID or parameters'
      t.timestamps
    end
  end
end
