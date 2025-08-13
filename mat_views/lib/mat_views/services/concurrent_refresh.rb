# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

module MatViews
  module Services
    # ConcurrentRefresh performs:
    #   REFRESH MATERIALIZED VIEW CONCURRENTLY <schema>.<rel>
    # It keeps the view readable during refresh, but requires a UNIQUE index.
    class ConcurrentRefresh < BaseService
      attr_reader :row_count_strategy

      # row_count_strategy: :estimated | :exact | nil | other
      def initialize(definition, row_count_strategy: :estimated)
        super(definition)
        @row_count_strategy = row_count_strategy
      end

      def run
        prep = prepare!
        return prep if prep

        sql = "REFRESH MATERIALIZED VIEW CONCURRENTLY #{qualified_rel}"

        conn.execute(sql)

        payload = { view: "#{schema}.#{rel}" }
        payload[:rows_count] = fetch_rows_count if row_count_strategy.present?

        ok(:updated,
           payload: payload,
           meta: { sql: sql, row_count_strategy: row_count_strategy, concurrent: true })
      rescue PG::ObjectInUse => e
        # Common lock/contention error during concurrent refreshes.
        error_response(e,
                       meta: { sql: sql, row_count_strategy: row_count_strategy, concurrent: true },
                       payload: { view: "#{schema}.#{rel}" })
      rescue StandardError => e
        error_response(e,
                       meta: { sql: sql, backtrace: Array(e.backtrace), row_count_strategy: row_count_strategy, concurrent: true },
                       payload: { view: "#{schema}.#{rel}" })
      end

      # ────────────────────────────────────────────────────────────────
      # internal
      # ────────────────────────────────────────────────────────────────

      def prepare!
        return err("Invalid view name format: #{definition.name.inspect}") unless valid_name?
        return err("Materialized view #{schema}.#{rel} does not exist") unless view_exists?
        return err("Materialized view #{schema}.#{rel} must have a unique index for concurrent refresh") unless unique_index_exists?

        nil
      end

      # ────────────────────────────────────────────────────────────────
      # helpers: validation / schema / pg introspection
      # (mirrors RegularRefresh for consistency)
      # ────────────────────────────────────────────────────────────────

      def valid_name?
        /\A[a-zA-Z_][a-zA-Z0-9_]*\z/.match?(definition.name.to_s)
      end

      # Any UNIQUE index on the matview satisfies the CONCURRENTLY requirement.
      def unique_index_exists?
        conn.select_value(<<~SQL).to_i.positive?
          SELECT COUNT(*)
          FROM pg_index i
          JOIN pg_class c ON c.oid = i.indrelid
          JOIN pg_namespace n ON n.oid = c.relnamespace
          WHERE n.nspname = #{conn.quote(schema)}
            AND c.relname = #{conn.quote(rel)}
            AND i.indisunique = TRUE
        SQL
      end

      # ────────────────────────────────────────────────────────────────
      # rows counting (same as RegularRefresh)
      # ────────────────────────────────────────────────────────────────

      def fetch_rows_count
        case row_count_strategy
        when :estimated then estimated_rows_count
        when :exact     then exact_rows_count
        end
      end

      # Fast/approx via pg_class.reltuples.
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

      # Accurate but heavier.
      def exact_rows_count
        conn.select_value("SELECT COUNT(*) FROM #{qualified_rel}").to_i
      end
    end
  end
end
