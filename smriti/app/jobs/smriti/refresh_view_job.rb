# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

##
# Top-level namespace for the smriti engine.
module Smriti
  ##
  # ActiveJob that handles `REFRESH MATERIALIZED VIEW` for a given
  # {Smriti::MatViewDefinition}.
  #
  # The job mirrors {Smriti::CreateViewJob}'s lifecycle:
  # it measures duration and persists state in {Smriti::MatViewRun}.
  #
  # The actual refresh implementation is delegated based on
  # `definition.refresh_strategy`:
  #
  # - `"concurrent"` → {Smriti::Services::ConcurrentRefresh}
  # - `"swap"`       → {Smriti::Services::SwapRefresh}
  # - otherwise      → {Smriti::Services::RegularRefresh}
  #
  # Row count reporting can be controlled via `row_count_strategy`:
  # - `:estimated` (default) - fast, approximate via reltuples
  # - `:exact` - accurate `COUNT(*)`
  # - `nil` - skip counting
  #
  # @see Smriti::MatViewDefinition
  # @see Smriti::MatViewRun
  # @see Smriti::Services::RegularRefresh
  # @see Smriti::Services::ConcurrentRefresh
  # @see Smriti::Services::SwapRefresh
  #
  # @example Enqueue a refresh with exact row count
  #   Smriti::RefreshViewJob.perform_later(definition.id, :exact)
  #
  # @example Enqueue using keyword-hash form
  #   Smriti::RefreshViewJob.perform_later(definition.id, row_count_strategy: :estimated)
  #
  class RefreshViewJob < ApplicationJob
    ##
    # Queue name for the job.
    #
    # Uses `Smriti.configuration.job_queue` when configured, otherwise `:default`.
    #
    queue_as { Smriti.configuration.job_queue || :default }

    ##
    # Perform the refresh job for the given materialised view definition.
    #
    # @api public
    #
    # @param mat_view_definition_id [Integer, String] ID of {Smriti::MatViewDefinition}.
    # @param row_count_strategy_arg [:Symbol, String] One of: `:estimated`, `:exact`, `:none` or `nil`.
    #
    # @return [Hash] Serialized {Smriti::ServiceResponse#to_h}:
    #   - `:status` [Symbol]
    #   - `:error` [String, nil]
    #   - `:duration_ms` [Integer]
    #   - `:meta` [Hash]
    #
    # @raise [StandardError] Re-raised on unexpected failure after marking the run failed.
    #
    def perform(mat_view_definition_id, row_count_strategy_arg = nil)
      definition = Smriti::MatViewDefinition.find(mat_view_definition_id)
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
    # @param definition [Smriti::MatViewDefinition]
    # @return [Class] One of the refresh service classes.
    #
    def service(definition)
      case definition.refresh_strategy
      when 'concurrent'
        Smriti::Services::ConcurrentRefresh
      when 'swap'
        Smriti::Services::SwapRefresh
      else
        Smriti::Services::RegularRefresh
      end
    end
  end
end
