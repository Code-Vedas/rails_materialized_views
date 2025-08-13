# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

module MatViews
  # DeleteViewJob handles DROP MATERIALIZED VIEW via the DeleteView service.
  # It mirrors CreateViewJob/RefreshViewJob: time the run and persist it in MatViewDeleteRun.
  class DeleteViewJob < ::ActiveJob::Base
    queue_as { MatViews.configuration.job_queue || :default }

    # perform(definition_id, cascade_arg = nil)
    # Supports Hash or boolean-ish flag: perform(id, cascade: true)
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

    def normalize_cascade?(arg)
      value = if arg.is_a?(Hash)
                arg[:cascade] || arg['cascade']
              else
                arg
              end
      cascade_value_trueish?(value)
    end

    # Returns true if the value represents a "truthy" cascade flag.
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

    def execute(definition, cascade:)
      started  = monotime
      # Use if_exists: true for idempotency in jobs
      response = MatViews::Services::DeleteView.new(definition, cascade: cascade, if_exists: true).run
      [response, elapsed_ms(started)]
    end

    def start_run(definition)
      MatViews::MatViewDeleteRun.create!(
        mat_view_definition: definition,
        status: :running,
        started_at: Time.current
      )
    end

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

    def fail_run!(run, exception)
      run.update!(
        finished_at: Time.current,
        duration_ms: run.duration_ms || 0,
        error: "#{exception.class}: #{exception.message}",
        status: :failed
      )
    end

    def monotime = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    def elapsed_ms(start) = ((monotime - start) * 1000).round
  end
end
