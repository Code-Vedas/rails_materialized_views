# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

##
# Top-level namespace for the mat_views engine.
module MatViews
  ##
  # ActiveRecord model that tracks the lifecycle of *runs* for
  # materialized views.
  #
  # Each record corresponds to a single attempt to mutate a materialized view
  # from a {MatViews::MatViewDefinition}, storing its status, timing, and
  # any associated error or metadata.
  #
  # This model provides an auditable history of view provisioning across
  # environments, useful for telemetry, dashboards, and debugging.
  #
  # @see MatViews::MatViewDefinition
  # @see MatViews::CreateViewJob
  #
  # @example Query recent successful runs
  #   MatViews::MatViewRun.status_success.order(created_at: :desc).limit(10)
  #
  # @example Check if a definition has any failed runs
  #   definition.mat_view_runs.status_failed.any?
  #
  class MatViewRun < ApplicationRecord
    ##
    # Underlying database table name.
    self.table_name = 'mat_view_runs'

    ##
    # The definition this run belongs to.
    #
    # @return [MatViews::MatViewDefinition]
    #
    belongs_to :mat_view_definition, class_name: 'MatViews::MatViewDefinition'

    ##
    # Status of the create run.
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

    # Operation type of the run.
    #
    # @!attribute [r] operation
    #   @return [Symbol] One of:
    #     - `:create` — initial creation of the materialized view
    #     - `:refresh` — refreshing an existing view
    #     - `:drop` — dropping the materialized view
    enum :operation, {
      create: 0,
      refresh: 1,
      drop: 2
    }, prefix: :operation

    ##
    # Validations
    #
    # Ensures that a status is always present.
    validates :status, presence: true

    ##
    # Scopes
    scope :create_runs, -> { where(operation: :create) }
    scope :refresh_runs, -> { where(operation: :refresh) }
    scope :drop_runs,    -> { where(operation: :drop) }

    def row_count
      meta['row_count']
    end
  end
end
