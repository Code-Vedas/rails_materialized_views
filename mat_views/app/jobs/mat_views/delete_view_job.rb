# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

##
# Top-level namespace for the mat_views engine.
module MatViews
  ##
  # ActiveJob that handles *deletion* of PostgreSQL materialized views via
  # {MatViews::Services::DeleteView}.
  #
  # This job mirrors {MatViews::CreateViewJob} and {MatViews::RefreshViewJob}:
  # it times the run and persists lifecycle state in {MatViews::MatViewDeleteRun}.
  #
  # @see MatViews::Services::DeleteView
  # @see MatViews::MatViewDefinition
  # @see MatViews::MatViewDeleteRun
  #
  # @example Enqueue a delete job
  #   MatViews::DeleteViewJob.perform_later(definition.id, cascade: true)
  #
  # @example Inline run (test/dev)
  #   MatViews::DeleteViewJob.new.perform(definition.id, false)
  #
  class DeleteViewJob < ::ActiveJob::Base
    ##
    # Queue name for the job.
    #
    # Uses `MatViews.configuration.job_queue` when configured, otherwise `:default`.
    #
    queue_as { MatViews.configuration.job_queue || :default }

    ##
    # Perform the job for the given materialized view definition.
    #
    # @api public
    #
    # @param definition_id [Integer, String] ID of {MatViews::MatViewDefinition}.
    # @param cascade_arg [Boolean, String, Integer, Hash, nil] Cascade option.
    #   Accepts:
    #   - `true/false`
    #   - `1` (treated as true)
    #   - `"true"`, `"1"`, `"yes"` (case-insensitive)
    #   - `{ cascade: true }` or `{ "cascade" => true }`
    #
    # @return [Hash] A serialized {MatViews::ServiceResponse#to_h}:
    #   - `:status` [Symbol] `:success`, `:failed`, etc.
    #   - `:payload` [Hash] response payload (also stored in run.meta)
    #   - `:error` [String, nil]
    #   - `:duration_ms` [Integer]
    #   - `:meta` [Hash]
    #
    # @raise [StandardError] Re-raised on unexpected failure after marking the run failed.
    #
    def perform(definition_id, cascade_arg = nil)
      cascade    = normalize_cascade?(cascade_arg)
      definition = MatViews::MatViewDefinition.find(definition_id)
      run        = start_run(definition)

      response, duration_ms = execute(definition, cascade: cascade)
      finalize_run!(run, response, duration_ms)
      response.to_h
    rescue StandardError => e
      fail_run!(run, e) if run
      raise e
    end

    private

    ##
    # Normalize cascade argument into a boolean.
    #
    # @api private
    # @param arg [Object] Raw cascade argument.
    # @return [Boolean] Whether to cascade drop.
    #
    def normalize_cascade?(arg)
      value = if arg.is_a?(Hash)
                arg[:cascade] || arg['cascade']
              else
                arg
              end
      cascade_value_trueish?(value)
    end

    ##
    # Evaluate if a value is "truthy" for cascade purposes.
    #
    # @api private
    # @param value [Object]
    # @return [Boolean]
    #
    def cascade_value_trueish?(value)
      case value
      when true
        true
      when String
        %w[true 1 yes].include?(value.strip.downcase)
      when Integer
        value == 1
      else
        false
      end
    end

    ##
    # Execute the delete service and measure duration.
    #
    # @api private
    # @param definition [MatViews::MatViewDefinition]
    # @param cascade [Boolean]
    # @return [Array(MatViews::ServiceResponse, Integer)]
    #
    def execute(definition, cascade:)
      started  = monotime
      response = MatViews::Services::DeleteView.new(definition, cascade: cascade, if_exists: true).run
      [response, elapsed_ms(started)]
    end

    ##
    # Begin a {MatViews::MatViewDeleteRun} row for lifecycle tracking.
    #
    # @api private
    # @param definition [MatViews::MatViewDefinition]
    # @return [MatViews::MatViewDeleteRun]
    #
    def start_run(definition)
      MatViews::MatViewDeleteRun.create!(
        mat_view_definition: definition,
        status: :running,
        started_at: Time.current
      )
    end

    ##
    # Finalize the run with success/failure, timing, and meta from the response.
    #
    # @api private
    # @param run [MatViews::MatViewDeleteRun]
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
    # @param run [MatViews::MatViewDeleteRun]
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
