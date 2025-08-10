# frozen_string_literal: true

module MatViews
  # CreateViewJob is an ActiveJob that handles the creation of materialized views.
  class CreateViewJob < ::ActiveJob::Base
    queue_as { MatViews.configuration.job_queue || :default }

    # perform(definition_id, force: false)
    def perform(definition_id, force_arg = nil)
      force = normalize_force(force_arg)

      definition = MatViews::MatViewDefinition.find(definition_id)
      run        = start_run(definition)

      response, duration_ms = execute(definition, force: force)
      finalize_run!(run, response, duration_ms)
      response.to_h
    rescue StandardError => e
      fail_run!(run, e) if run
      raise
    end

    private

    def normalize_force(arg)
      case arg
      when Hash
        arg[:force] || arg['force'] || false
      else
        !!arg
      end
    end

    def execute(definition, force:)
      started  = monotime
      response = MatViews::Services::CreateView.new(definition, force: force).run
      [response, elapsed_ms(started)]
    end

    def start_run(definition)
      MatViews::MatViewCreateRun.create!(
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
      return unless run

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
