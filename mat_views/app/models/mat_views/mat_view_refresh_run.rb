# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

##
# Top-level namespace for the mat_views engine.
module MatViews
  ##
  # ActiveRecord model that tracks the lifecycle of **refresh runs** for
  # PostgreSQL materialized views.
  #
  # Each record represents a single execution of a refresh operation initiated
  # from a {MatViews::MatViewDefinition}, capturing status, timing, metadata,
  # and any error details, enabling auditing and operational insights.
  #
  # @see MatViews::MatViewDefinition
  # @see MatViews::RefreshViewJob
  #
  # @example Recent successful refreshes
  #   MatViews::MatViewRefreshRun.status_success.order(created_at: :desc).limit(20)
  #
  # @example Failed count for a definition
  #   definition.mat_view_refresh_runs.status_failed.count
  #
  class MatViewRefreshRun < ApplicationRecord
    ##
    # Underlying database table name.
    self.table_name = 'mat_view_refresh_runs'

    ##
    # The definition this run belongs to.
    #
    # @return [MatViews::MatViewDefinition]
    #
    belongs_to :mat_view_definition, class_name: 'MatViews::MatViewDefinition'

    ##
    # Status of the refresh run.
    #
    # @!attribute [r] status
    #   @return [Symbol] One of:
    #     - `:pending` — queued but not yet started
    #     - `:running` — currently executing
    #     - `:success` — completed successfully
    #     - `:failed` — encountered an error
    #
    enum :status, {
      pending: 0,
      running: 1,
      success: 2,
      failed: 3
    }, prefix: :status

    ##
    # Validations
    #
    # Ensures that a status is always present.
    validates :status, presence: true
  end
end
