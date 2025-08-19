# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

##
# Top-level namespace for the mat_views engine.
module MatViews
  ##
  # ActiveJob that handles *creation* of PostgreSQL materialized views for a
  # given {MatViews::MatViewDefinition}.
  #
  # The job:
  # 1. Normalizes the `force` argument.
  # 2. Looks up the target {MatViews::MatViewDefinition}.
  # 3. Starts a {MatViews::MatViewCreateRun} row to track lifecycle/timing.
  # 4. Executes {MatViews::Services::CreateView}.
  # 5. Finalizes the run with success/failure, duration, and payload meta.
  #
  # @see MatViews::Services::CreateView
  # @see MatViews::MatViewDefinition
  # @see MatViews::MatViewCreateRun
  #
  # @example Enqueue a create job
  #   MatViews::CreateViewJob.perform_later(definition.id, force: true)
  #
  # @example Inline run (test/dev)
  #   MatViews::CreateViewJob.new.perform(definition.id, false)
  #
  class CreateViewJob < ::ActiveJob::Base
    ##
    # Queue name for the job.
    #
    # Uses `MatViews.configuration.job_queue` when configured, otherwise `:default`.
    #
    # @return [void]
    #
    queue_as { MatViews.configuration.job_queue || :default }

    ##
    # Perform the job for the given materialized view definition.
    #
    # @api public
    #
    # @param definition_id [Integer, String] ID of {MatViews::MatViewDefinition}.
    # @param force_arg [Boolean, Hash, nil] Optional flag or hash (`{ force: true }`)
    #   to force creation (drop/recreate) when supported by the service.
    #
    # @return [Hash] A serialized {MatViews::ServiceResponse#to_h}:
    #   - `:status` [Symbol] one of `:ok, :created, :updated, :noop, :error`
    #   - `:payload` [Hash] service-specific payload (also stored in run.meta)
    #   - `:error` [String, nil] error message if any
    #   - `:duration_ms` [Integer, nil]
    #   - `:meta` [Hash]
    #
    # @raise [StandardError] Re-raised on unexpected failure after marking the run failed.
    #
    # @see MatViews::Services::CreateView
    #
    def perform(definition_id, force_arg = nil)
      force = normalize_force(force_arg)

      definition = MatViews::MatViewDefinition.find(definition_id)
      run        = start_run(definition)

      response, duration_ms = execute(definition, force: force)
      finalize_run!(run, response, duration_ms)
      response.to_h
    rescue StandardError => e
      fail_run!(run, e) if run
      raise e
    end

    private

    ##
    # Normalize the `force` argument into a boolean.
    #
    # Accepts either a boolean-ish value or a Hash (e.g., `{ force: true }` or `{ "force" => true }`).
    #
    # @api private
    #
    # @param arg [Object] Raw argument; commonly `true/false`, `nil`, or `Hash`.
    # @return [Boolean] Coerced force flag.
    #
    def normalize_force(arg)
      case arg
      when Hash
        arg[:force] || arg['force'] || false
      else
        !!arg
      end
    end

    ##
    # Execute the create service and measure duration.
    #
    # @api private
    #
    # @param definition [MatViews::MatViewDefinition]
    # @param force [Boolean]
    # @return [Array(MatViews::ServiceResponse, Integer)] response and elapsed ms.
    #
    def execute(definition, force:)
      started  = monotime
      response = MatViews::Services::CreateView.new(definition, force: force).run
      [response, elapsed_ms(started)]
    end

    ##
    # Begin a {MatViews::MatViewCreateRun} row for lifecycle tracking.
    #
    # @api private
    #
    # @param definition [MatViews::MatViewDefinition]
    # @return [MatViews::MatViewCreateRun] newly created run with `status: :running`
    #
    def start_run(definition)
      MatViews::MatViewCreateRun.create!(
        mat_view_definition: definition,
        status: :running,
        started_at: Time.current
      )
    end

    ##
    # Finalize the run with success/failure, timing, and meta from the response payload.
    #
    # @api private
    #
    # @param run [MatViews::MatViewCreateRun]
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
    # @param run [MatViews::MatViewCreateRun]
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
    # @return [Float] seconds from a monotonic source.
    #
    def monotime = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    ##
    # Convert a monotonic start time to elapsed milliseconds.
    #
    # @api private
    # @param start [Float] monotonic seconds.
    # @return [Integer] elapsed milliseconds.
    #
    def elapsed_ms(start) = ((monotime - start) * 1000).round
  end
end
