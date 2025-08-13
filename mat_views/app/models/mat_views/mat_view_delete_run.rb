# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

module MatViews
  # MatViewDeleteRun is an ActiveRecord model that tracks the status of materialized view delete operations.
  class MatViewDeleteRun < ApplicationRecord
    self.table_name = 'mat_view_delete_runs'

    belongs_to :mat_view_definition, class_name: 'MatViews::MatViewDefinition'

    enum :status, {
      pending: 0, # The delete operation is queued but not yet started.
      running: 1, # The delete operation is currently in progress.
      success: 2, # The delete operation completed successfully.
      failed: 3   # The delete operation encountered an error.
    }, prefix: :status

    validates :status, presence: true
  end
end
