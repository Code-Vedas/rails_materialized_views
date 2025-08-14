# frozen_string_literal: true

require 'csv'

module MatViewsDemo
  # Benchmarks regular (baseline) SQL vs reading from the MV.
  class Validator
    attr_reader :definition, :iterations, :connection

    def initialize(definition, iterations: 5, connection: ActiveRecord::Base.connection)
      @definition = definition
      @iterations = Integer(iterations || 5)
      @iterations = 1 if @iterations < 1
      @connection = connection
    end

    # Returns a Hash with timing arrays and simple stats
    # {
    #   view: "mv_user_activity",
    #   iterations: 5,
    #   baseline_ms: [..], baseline_avg_ms: 12, baseline_min_ms: 10, baseline_max_ms: 15,
    #   mv_ms: [..],       mv_avg_ms: 3,  mv_min_ms: 2,  mv_max_ms: 4,
    #   speedup_avg: 4.0,
    #   rows_baseline: 1234,
    #   rows_mv: 1234
    # }
    def run
      baseline_times = []
      mv_times       = []
      rows_baseline  = nil
      rows_mv        = nil

      iterations.times do
        baseline_times << time_ms { rows_baseline = baseline_count }
        mv_times       << time_ms { rows_mv       = mv_count }
      end

      {
        view: definition.name,
        iterations: iterations,
        baseline_ms: baseline_times,
        baseline_avg_ms: avg(baseline_times),
        baseline_min_ms: baseline_times.min,
        baseline_max_ms: baseline_times.max,
        mv_ms: mv_times,
        mv_avg_ms: avg(mv_times),
        mv_min_ms: mv_times.min,
        mv_max_ms: mv_times.max,
        speedup_avg: speedup(avg(baseline_times), avg(mv_times)),
        rows_baseline: rows_baseline,
        rows_mv: rows_mv
      }
    end

    private

    def baseline_count
      sql = "SELECT COUNT(*) FROM (#{definition.sql}) AS subq"
      connection.select_value(sql).to_i
    end

    def mv_count
      rel = %("#{definition.name}")
      connection.select_value("SELECT COUNT(*) FROM #{rel}").to_i
    end

    def time_ms
      t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      yield
      ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0) * 1000).round
    end

    def avg(arr)
      return 0 if arr.empty?

      (arr.sum.to_f / arr.size).round
    end

    def speedup(baseline_avg, mv_avg)
      return 0.0 if mv_avg.to_f <= 0.0

      (baseline_avg.to_f / mv_avg).round(2)
    end
  end
end
