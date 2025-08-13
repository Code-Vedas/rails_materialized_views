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
      case arg
      when Hash
        v = arg[:cascade] || arg['cascade']
        !!(v == true || v.to_s.strip.casecmp('true').zero? || v.to_s.strip == '1' || v.to_s.strip.casecmp('yes').zero?)
      else
        !!arg
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
