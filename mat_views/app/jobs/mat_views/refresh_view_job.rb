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
  # - `:estimated` (default) — fast, approximate via reltuples
  # - `:exact` — accurate `COUNT(*)`
  # - `nil` — skip counting
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
  class RefreshViewJob < ::ActiveJob::Base
    ##
    # Queue name for the job.
    #
    # Uses `MatViews.configuration.job_queue` when configured, otherwise `:default`.
    #
    queue_as { MatViews.configuration.job_queue || :default }

    ##
    # Perform the job for the given materialized view definition.
    #
    # Accepts either a symbol/string (`:estimated`, `:exact`) or a hash
    # (`{ row_count_strategy: :exact }`) for `strategy_arg`.
    #
    # @api public
    #
    # @param definition_id [Integer, String] ID of {MatViews::MatViewDefinition}.
    # @param strategy_arg [Symbol, String, Hash, nil] Row count strategy override.
    #   When a Hash, looks for `:row_count_strategy` / `"row_count_strategy"`.
    #
    # @return [Hash] Serialized {MatViews::ServiceResponse#to_h}:
    #   - `:status` [Symbol]
    #   - `:payload` [Hash]
    #   - `:error` [String, nil]
    #   - `:duration_ms` [Integer]
    #   - `:meta` [Hash]
    #
    # @raise [StandardError] Re-raised on unexpected failure after marking the run failed.
    #
    def perform(definition_id, strategy_arg = nil)
      row_count_strategy = normalize_strategy(strategy_arg)
      definition = MatViews::MatViewDefinition.find(definition_id)
      run        = start_run(definition)

      response, duration_ms = execute(definition, row_count_strategy: row_count_strategy)
      finalize_run!(run, response, duration_ms)
      response.to_h
    rescue StandardError => e
      fail_run!(run, e) if run
      raise e
    end

    private

    ##
    # Normalize the strategy argument into a symbol or default.
    #
    # @api private
    #
    # @param arg [Symbol, String, Hash, nil]
    # @return [Symbol] One of `:estimated`, `:exact`, or `:estimated` by default.
    #
    def normalize_strategy(arg)
      case arg
      when Hash
        (arg[:row_count_strategy] || arg['row_count_strategy'] || :estimated).to_sym
      when String, Symbol
        arg.to_sym
      else
        :estimated
      end
    end

    ##
    # Execute the appropriate refresh service and measure duration.
    #
    # @api private
    #
    # @param definition [MatViews::MatViewDefinition]
    # @param row_count_strategy [Symbol, nil]
    # @return [Array(MatViews::ServiceResponse, Integer)] response and elapsed ms.
    #
    def execute(definition, row_count_strategy:)
      started  = monotime
      response = service(definition).new(definition, row_count_strategy: row_count_strategy).run
      [response, elapsed_ms(started)]
    end

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

    ##
    # Begin a {MatViews::MatViewRun} row for lifecycle tracking.
    #
    # @api private
    #
    # @param definition [MatViews::MatViewDefinition]
    # @return [MatViews::MatViewRun]
    #
    def start_run(definition)
      MatViews::MatViewRun.create!(
        mat_view_definition: definition,
        status: :running,
        started_at: Time.current,
        operation: :refresh
      )
    end

    ##
    # Finalize the run with success/failure, timing, and meta from the response.
    #
    # @api private
    #
    # @param run [MatViews::MatViewRun]
    # @param response [MatViews::ServiceResponse]
    # @param duration_ms [Integer]
    # @return [void]
    #
    def finalize_run!(run, response, duration_ms)
      base_attrs = {
        finished_at: Time.current,
        duration_ms: duration_ms,
        meta: response.payload || {}
      }

      if response.success?
        run.update!(base_attrs.merge(status: :success, error: nil))
      else
        run.update!(base_attrs.merge(status: :failed, error: response.error.to_s.presence))
      end
    end

    ##
    # Mark the run failed due to an exception.
    #
    # @api private
    #
    # @param run [MatViews::MatViewRun]
    # @param exception [Exception]
    # @return [void]
    #
    def fail_run!(run, exception)
      run.update!(
        finished_at: Time.current,
        duration_ms: run.duration_ms || 0,
        error: "#{exception.class}: #{exception.message}",
        status: :failed
      )
    end

    ##
    # Monotonic clock getter (for elapsed-time measurement).
    #
    # @api private
    # @return [Float] seconds
    #
    def monotime = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    ##
    # Convert monotonic start time to elapsed milliseconds.
    #
    # @api private
    # @param start [Float]
    # @return [Integer] elapsed ms
    #
    def elapsed_ms(start) = ((monotime - start) * 1000).round
  end
end
