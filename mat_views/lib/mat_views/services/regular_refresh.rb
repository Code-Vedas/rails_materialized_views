# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

module MatViews
  module Services
    ##
    # Service that executes a standard (locking) `REFRESH MATERIALIZED VIEW`.
    #
    # This is the safest option for simple or low-frequency updates where
    # blocking reads during refresh is acceptable.
    #
    # Supports optional row counting strategies:
    # - `:estimated` → uses `pg_class.reltuples` (fast, approximate)
    # - `:exact`     → runs `COUNT(*)` (accurate, but potentially slow)
    # - `nil`        → no row count included in payload
    #
    # @return [MatViews::ServiceResponse]
    #
    # @example
    #   svc = MatViews::Services::RegularRefresh.new(defn)
    #   svc.run
    #
    class RegularRefresh < BaseService
      ##
      # The row count strategy requested.
      # One of `:estimated`, `:exact`, `nil`, or unrecognized symbol.
      #
      # @return [Symbol, nil]
      attr_reader :row_count_strategy

      ##
      # @param definition [MatViews::MatViewDefinition]
      # @param row_count_strategy [Symbol, nil] row counting mode
      def initialize(definition, row_count_strategy: :estimated)
        super(definition)
        @row_count_strategy = row_count_strategy
      end

      ##
      # Perform the refresh.
      #
      # Steps:
      # - Validate name & existence.
      # - Run `REFRESH MATERIALIZED VIEW`.
      # - Optionally compute row count.
      #
      # @return [MatViews::ServiceResponse]
      #
      def run
        prep = prepare!
        return prep if prep

        sql = "REFRESH MATERIALIZED VIEW #{qualified_rel}"

        conn.execute(sql)

        payload = { view: "#{schema}.#{rel}" }
        payload[:row_count] = fetch_rows_count if row_count_strategy.present?

        ok(:updated,
           payload: payload,
           meta: { sql: sql, row_count_strategy: row_count_strategy })
      rescue StandardError => e
        error_response(
          e,
          meta: {
            sql: sql,
            backtrace: Array(e.backtrace),
            row_count_strategy: row_count_strategy
          },
          payload: { view: "#{schema}.#{rel}" }
        )
      end

      private

      # ────────────────────────────────────────────────────────────────
      # internal
      # ────────────────────────────────────────────────────────────────

      ##
      # Validate name and existence of the materialized view.
      #
      # @api private
      # @return [MatViews::ServiceResponse, nil]
      #
      def prepare!
        return err("Invalid view name format: #{definition.name.inspect}") unless valid_name?
        return err("Materialized view #{schema}.#{rel} does not exist") unless view_exists?

        nil
      end

      # ────────────────────────────────────────────────────────────────
      # rows counting
      # ────────────────────────────────────────────────────────────────

      ##
      # Pick the appropriate row count method.
      #
      # @api private
      # @return [Integer, nil]
      #
      def fetch_rows_count
        case row_count_strategy
        when :estimated then estimated_rows_count
        when :exact     then exact_rows_count
        end
      end

      ##
      # Fast/approx via `pg_class.reltuples`.
      # Updated by `ANALYZE` and autovacuum.
      #
      # @api private
      # @return [Integer]
      #
      def estimated_rows_count
        conn.select_value(<<~SQL).to_i
          SELECT COALESCE(c.reltuples::bigint, 0)
          FROM pg_class c
          JOIN pg_namespace n ON n.oid = c.relnamespace
          WHERE c.relkind IN ('m','r','p')
            AND n.nspname = #{conn.quote(schema)}
            AND c.relname = #{conn.quote(rel)}
          LIMIT 1
        SQL
      end

      ##
      # Accurate count via `COUNT(*)`.
      # Potentially slow on large materialized views.
      #
      # @api private
      # @return [Integer]
      #
      def exact_rows_count
        conn.select_value("SELECT COUNT(*) FROM #{qualified_rel}").to_i
      end
    end
  end
end
