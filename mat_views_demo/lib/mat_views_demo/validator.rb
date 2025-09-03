# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

require 'csv'

module MatViewsDemo
  # Validator benchmarks query performance by comparing:
  # - A baseline SQL query (the raw definition SQL wrapped in COUNT(*))
  # - The equivalent query against the materialized view (MV)
  #
  # It executes a configurable number of iterations and returns timing
  # statistics for both approaches, along with row counts and relative speedup.
  #
  # Example result:
  # {
  #   view: "mv_user_activity",
  #   iterations: 5,
  #   baseline_ms: [..], baseline_avg_ms: 12, baseline_min_ms: 10, baseline_max_ms: 15,
  #   mv_ms: [..],       mv_avg_ms: 3,  mv_min_ms: 2,  mv_max_ms: 4,
  #   speedup_avg: 4.0,
  #   rows_baseline: 1234,
  #   rows_mv: 1234
  # }
  class Validator
    attr_reader :definition, :iterations, :connection

    # @param definition [MatViews::MatViewDefinition] the materialized view definition
    # @param iterations [Integer] how many times to run each benchmark (default: 5)
    # @param connection [ActiveRecord::ConnectionAdapters::PostgreSQLAdapter] DB connection
    def initialize(definition, iterations: 5, connection: ActiveRecord::Base.connection)
      @definition = definition
      @iterations = Integer(iterations || 5)
      @iterations = 1 if @iterations < 1
      @connection = connection
    end

    # Run the benchmark and return a stats hash.
    #
    # @return [Hash] results with timing arrays, stats, and row counts
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

    # Count rows from baseline SQL (definition.sql wrapped in COUNT(*)).
    #
    # @private
    # @return [Integer] row count from the baseline query
    #
    # This method wraps the definition SQL in a COUNT(*) subquery to get the total row count.
    # It executes the SQL against the database connection and returns the count as an integer.
    def baseline_count
      sql = "SELECT COUNT(*) FROM (#{definition.sql}) AS subq"
      connection.select_value(sql).to_i
    end

    # Count rows directly from the materialized view.
    #
    # @private
    # @return [Integer] row count from the materialized view
    #
    # This method executes a simple COUNT(*) query against the materialized view defined by
    # the MatViewDefinition. It returns the total number of rows in the view.
    def mv_count
      rel = %("#{definition.name}")
      connection.select_value("SELECT COUNT(*) FROM #{rel}").to_i
    end

    # Measure execution time in milliseconds for a block.
    #
    # @private
    # @yield [Block] the code block to measure
    # @return [Integer] elapsed time in milliseconds
    #
    # This method captures the start time, yields to the block, and calculates the elapsed time
    # in milliseconds. It returns the rounded value of the elapsed time.
    def time_ms
      t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      yield
      ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0) * 1000).round
    end

    # Compute average of an array of integers, rounded.
    #
    # @private
    # @param arr [Array<Integer>] array of integers to average
    # @return [Integer] rounded average value
    #
    # This method calculates the average of the given array of integers and rounds it to the nearest integer.
    # If the array is empty, it returns 0.
    def avg(arr)
      return 0 if arr.empty?

      (arr.sum.to_f / arr.size).round
    end

    # Compute speedup ratio baseline/mv.
    #
    # @private
    # @param baseline_avg [Integer] average time of the baseline query in ms
    # @param mv_avg [Integer] average time of the materialized view query in ms
    # @return [Float] speedup factor, rounded to 2 decimal places
    #
    # This method calculates how many times faster the materialized view is compared to the baseline query.
    # If the materialized view average time is zero or less, it returns 0.0 to avoid division by zero.
    def speedup(baseline_avg, mv_avg)
      return 0.0 if mv_avg.to_f <= 0.0

      (baseline_avg.to_f / mv_avg).round(2)
    end
  end
end
