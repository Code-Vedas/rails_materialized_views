# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

# This migration creates the mat_view_runs table, which tracks the mutation runs(create,refresh,drop) of materialised views.
# It includes references to the materialised view definition, status, operation type, timestamps,
# duration, error messages, and additional metadata.
class CreateMatViewRuns < ActiveRecord::Migration[7.1]
  def change
    create_table :mat_view_runs do |t|
      t.references :mat_view_definition,
                   null: false,
                   foreign_key: true,
                   comment: 'Reference to the materialised view definition'

      # 0=running, 1=success, 2=failed
      t.integer  :status, null: false, default: 0, comment: '0=running,1=success,2=failed'
      # 0=create, 1=refresh, 2=drop
      t.integer  :operation, null: false, default: 0, comment: '0=create,1=refresh,2=drop'
      t.datetime :started_at, comment: 'Timestamp when the operation started'
      t.datetime :finished_at, comment: 'Timestamp when the operation finished'
      t.integer  :duration_ms, comment: 'Duration of the operation in milliseconds'
      t.jsonb :error, comment: 'Error details if the operation failed. :message, :class, :backtrace'
      t.jsonb :meta, null: false, default: {}, comment: 'Additional metadata about the run, such as job ID, row count or parameters'

      t.timestamps
    end
  end
end
