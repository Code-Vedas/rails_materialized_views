# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

module MatViews
  # MatViewDefinition represents a materialized view definition in the database.
  #
  # It includes validations for the view name and SQL query, and provides methods
  # to refresh the materialized view.
  #
  # The class is responsible for managing the lifecycle of materialized views,
  # including their creation, validation, and refresh operations.
  class MatViewDefinition < ApplicationRecord
    self.table_name = 'mat_view_definitions'

    has_many :mat_view_refresh_runs, dependent: :destroy, class_name: 'MatViews::MatViewRefreshRun'
    has_many :mat_view_create_runs, dependent: :destroy, class_name: 'MatViews::MatViewCreateRun'

    validates :name, presence: true, uniqueness: true, format: { with: /\A[a-zA-Z_][a-zA-Z0-9_]*\z/ }
    validates :sql, presence: true, format: { with: /\A\s*SELECT/i, message: 'must begin with a SELECT' }

    enum :refresh_strategy, { regular: 0, concurrent: 1, swap: 2 }
  end
end
