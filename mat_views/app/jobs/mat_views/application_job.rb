# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

##
# Top-level namespace for the mat_views engine.
#
# All classes, modules, and services for materialized view management
# are defined under this namespace.
#
# @example Accessing a job
#   MatViews::ApplicationJob
#
module MatViews
  ##
  # Base class for all background jobs in the mat_views engine.
  #
  # Inherits from {ActiveJob::Base} and provides a common superclass
  # for engine jobs such as {MatViews::CreateViewJob} and {MatViews::RefreshViewJob}.
  #
  # @abstract
  #
  # @see MatViews::CreateViewJob
  # @see MatViews::RefreshViewJob
  # @see MatViews::DeleteViewJob
  #
  # @example Defining a custom job
  #   class MyCustomJob < MatViews::ApplicationJob
  #     def perform(definition_id)
  #       # custom logic here
  #     end
  #   end
  #
  class ApplicationJob < ActiveJob::Base
    private

    def record_run(definition, operation, &)
      start = monotime
      run = start_run(definition, operation)
      response = yield
      finalize_run(run, response, elapsed_ms(start))
      response.to_h
    rescue StandardError => e
      fail_run(run, e, elapsed_ms(start))
      raise e
    end

    ##
    # Begin a {MatViews::MatViewRun} row for lifecycle tracking.
    #
    # @api private
    #
    # @return [MatViews::MatViewRun]
    #
    def start_run(definition, operation)
      MatViews::MatViewRun.create!(
        mat_view_definition: definition,
        status: :running,
        started_at: Time.current,
        operation: operation
      )
    end

    ##
    # Finalize the run with success/failure, timing, and meta from the response.
    #
    # @api private
    #
    # @param run [MatViews::MatViewRun]
    # @param response [MatViews::ServiceResponse, nil] may be nil if exception raised
    # @param duration_ms [Integer]
    # @return [void]
    #
    def finalize_run(run, response, duration_ms)
      base_attrs = {
        finished_at: Time.current,
        duration_ms: duration_ms,
        meta: { request: response.request, response: response.response }.compact
      }

      if response.success?
        run.update!(base_attrs.merge(status: :success, error: nil))
      else
        run.update!(base_attrs.merge(status: :failed, error: response.error))
      end
    end

    ##
    # Mark the run failed due to an exception.
    #
    # @api private
    #
    # @param run [MatViews::MatViewRun]
    # @param exception [Exception]
    # @param duration_ms [Integer]
    # @return [void]
    #
    def fail_run(run, exception, duration_ms)
      run&.update!(
        error: exception.mv_serialize_error,
        finished_at: Time.current,
        duration_ms: duration_ms,
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

    ##
    # Normalize the strategy argument into a symbol or default.
    #
    # @api private
    #
    # @param arg [Symbol, String, nil]
    # @return [Symbol] One of `:estimated`, `:exact`, or `:none` by default.
    #
    def normalize_strategy(arg)
      case arg
      when String, Symbol
        arg.to_sym
      else
        :none
      end
    end
  end
end
