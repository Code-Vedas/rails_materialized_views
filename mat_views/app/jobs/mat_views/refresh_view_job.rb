# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

module MatViews
  # RefreshViewJob is an ActiveJob that handles REFRESH MATERIALIZED VIEW.
  # It mirrors CreateViewJob's lifecycle: time the run and persist it in MatViewRefreshRun.
  class RefreshViewJob < ::ActiveJob::Base
    queue_as { MatViews.configuration.job_queue || :default }

    # perform(definition_id, row_count_strategy: :estimated)
    # Also supports symbol/string argument: perform(definition_id, :exact)
    def perform(definition_id, strategy_arg = nil)
      strategy   = normalize_strategy(strategy_arg)
      definition = MatViews::MatViewDefinition.find(definition_id)
      run        = start_run(definition)

      response, duration_ms = execute(definition, row_count_strategy: strategy)
      finalize_run!(run, response, duration_ms)
      response.to_h
    rescue StandardError => e
      fail_run!(run, e) if run
      raise e
    end

    private

    def normalize_strategy(arg)
      case arg
      when Hash
        (arg[:row_count_strategy] || arg['row_count_strategy'] || arg[:strategy] || arg['strategy'] || :estimated).to_sym
      when String, Symbol
        arg.to_sym
      else
        :estimated
      end
    end

    def execute(definition, row_count_strategy:)
      started  = monotime
      response = service(definition).new(definition, row_count_strategy: row_count_strategy).run
      [response, elapsed_ms(started)]
    end

    def service(definition)
      case definition.refresh_strategy
      when 'concurrent'
        MatViews::Services::ConcurrentRefresh
      else
        MatViews::Services::RegularRefresh
      end
    end

    def start_run(definition)
      MatViews::MatViewRefreshRun.create!(
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
