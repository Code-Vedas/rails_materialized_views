# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

##
# Top-level namespace for the mat_views engine.
module MatViews
  ##
  # ActiveJob that handles `REFRESH MATERIALIZED VIEW` for a given
  # {MatViews::MatViewDefinition}.
  #
  # The job mirrors {MatViews::CreateViewJob}'s lifecycle:
  # it measures duration and persists state in {MatViews::MatViewRun}.
  #
  # The actual refresh implementation is delegated based on
  # `definition.refresh_strategy`:
  #
  # - `"concurrent"` → {MatViews::Services::ConcurrentRefresh}
  # - `"swap"`       → {MatViews::Services::SwapRefresh}
  # - otherwise      → {MatViews::Services::RegularRefresh}
  #
  # Row count reporting can be controlled via `row_count_strategy`:
  # - `:estimated` (default) - fast, approximate via reltuples
  # - `:exact` - accurate `COUNT(*)`
  # - `nil` - skip counting
  #
  # @see MatViews::MatViewDefinition
  # @see MatViews::MatViewRun
  # @see MatViews::Services::RegularRefresh
  # @see MatViews::Services::ConcurrentRefresh
  # @see MatViews::Services::SwapRefresh
  #
  # @example Enqueue a refresh with exact row count
  #   MatViews::RefreshViewJob.perform_later(definition.id, :exact)
  #
  # @example Enqueue using keyword-hash form
  #   MatViews::RefreshViewJob.perform_later(definition.id, row_count_strategy: :estimated)
  #
  class RefreshViewJob < ApplicationJob
    ##
    # Queue name for the job.
    #
    # Uses `MatViews.configuration.job_queue` when configured, otherwise `:default`.
    #
    queue_as { MatViews.configuration.job_queue || :default }

    ##
    # Perform the refresh job for the given materialised view definition.
    #
    # @api public
    #
    # @param mat_view_definition_id [Integer, String] ID of {MatViews::MatViewDefinition}.
    # @param row_count_strategy_arg [:Symbol, String] One of: `:estimated`, `:exact`, `:none` or `nil`.
    #
    # @return [Hash] Serialized {MatViews::ServiceResponse#to_h}:
    #   - `:status` [Symbol]
    #   - `:error` [String, nil]
    #   - `:duration_ms` [Integer]
    #   - `:meta` [Hash]
    #
    # @raise [StandardError] Re-raised on unexpected failure after marking the run failed.
    #
    def perform(mat_view_definition_id, row_count_strategy_arg = nil)
      definition = MatViews::MatViewDefinition.find(mat_view_definition_id)
      record_run(definition, :refresh) do
        service(definition).new(definition, row_count_strategy: normalize_strategy(row_count_strategy_arg)).call
      end
    end

    private

    ##
    # Select the refresh service class based on the definition's strategy.
    #
    # @api private
    #
    # @param definition [MatViews::MatViewDefinition]
    # @return [Class] One of the refresh service classes.
    #
    def service(definition)
      case definition.refresh_strategy
      when 'concurrent'
        MatViews::Services::ConcurrentRefresh
      when 'swap'
        MatViews::Services::SwapRefresh
      else
        MatViews::Services::RegularRefresh
      end
    end
  end
end
