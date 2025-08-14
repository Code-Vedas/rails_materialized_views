# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

# This migration creates the mat_view_delete_runs table,
# which stores information about delete runs for materialized views.
# It includes fields for the associated mat_view_definition, status, timestamps for start and finish,
# duration in milliseconds, error messages, and additional metadata.
class CreateMatViewDeleteRuns < ActiveRecord::Migration[7.1]
  def change
    create_table :mat_view_delete_runs do |t|
      t.references :mat_view_definition,
                   null: false,
                   foreign_key: true,
                   comment: 'Reference to the materialized view definition being deleted from'

      # 0=pending, 1=running, 2=success, 3=failed
      t.integer  :status, null: false,
                          default: 0, comment: '0=pending,1=running,2=success,3=failed'
      t.datetime :started_at,
                 comment: 'Timestamp when the delete operation started'
      t.datetime :finished_at,
                 comment: 'Timestamp when the delete operation finished'
      t.integer :duration_ms,
                comment: 'Duration of the delete operation in milliseconds'
      t.text :error,
             comment: 'Error message if the delete operation failed'
      t.jsonb :meta, default: {},
                     comment: 'Additional metadata about the delete run, such as job ID or parameters'
      t.timestamps
    end
  end
end
