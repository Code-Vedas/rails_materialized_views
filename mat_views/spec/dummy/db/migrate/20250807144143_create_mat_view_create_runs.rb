# frozen_string_literal: true

# This migration creates the mat_view_create_runs table, which tracks the creation runs of materialized views.
# It includes fields for the associated materialized view definition, status of the run, timestamps for start and finish,
# duration of the run, any error messages, and additional metadata.
class CreateMatViewCreateRuns < ActiveRecord::Migration[7.1]
  def change
    create_table :mat_view_create_runs do |t|
      t.references :mat_view_definition,
                   null: false,
                   foreign_key: true,
                   comment: 'Reference to the materialized view definition being created'

      # 0=pending, 1=running, 2=success, 3=failed
      t.integer  :status, null: false, default: 0, comment: '0=pending,1=running,2=success,3=failed'
      t.datetime :started_at, comment: 'Timestamp when the creation operation started'
      t.datetime :finished_at, comment: 'Timestamp when the creation operation finished'
      t.integer  :duration_ms, comment: 'Duration of the creation operation in milliseconds'
      t.text     :error, comment: 'Error message if the creation operation failed'
      t.jsonb    :meta, null: false, default: {}, comment: 'Additional metadata about the creation run, such as job ID or parameters'

      t.timestamps
    end
  end
end
