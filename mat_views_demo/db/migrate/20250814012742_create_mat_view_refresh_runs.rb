# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

# This migration creates the mat_view_refresh_runs table,
# which stores information about refresh runs for materialized views.
# It includes fields for the associated mat_view_definition, status, timestamps for start and finish,
# duration in milliseconds, row count, error messages, and additional metadata.
class CreateMatViewRefreshRuns < ActiveRecord::Migration[7.1]
  def change
    create_table :mat_view_refresh_runs do |t|
      t.references :mat_view_definition,
                   null: false,
                   foreign_key: true,
                   comment: 'Reference to the materialized view definition being refreshed'

      # 0=pending, 1=running, 2=success, 3=failed
      t.integer  :status, null: false,
                          default: 0, comment: '0=pending,1=running,2=success,3=failed'
      t.datetime :started_at,
                 comment: 'Timestamp when the refresh operation started'
      t.datetime :finished_at,
                 comment: 'Timestamp when the refresh operation finished'
      t.integer :duration_ms,
                comment: 'Duration of the refresh operation in milliseconds'
      t.integer :rows_count,
                comment: 'Number of rows in the materialized view after refresh'
      t.text :error,
             comment: 'Error message if the refresh operation failed'
      t.jsonb :meta, default: {},
                     comment: 'Additional metadata about the refresh run, such as job ID or parameters'
      t.timestamps
    end
  end
end
