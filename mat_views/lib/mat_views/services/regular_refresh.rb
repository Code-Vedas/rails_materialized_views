# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

module MatViews
  module Services
    # RegularRefresh executes a standard (locking) REFRESH MATERIALIZED VIEW.
    # It is the safest option for simple / low-frequency updates.
    class RegularRefresh < BaseService
      attr_reader :row_count_strategy

      # row_count_strategy: :estimated | :exact | nil
      def initialize(definition, row_count_strategy: :estimated)
        super(definition)
        @row_count_strategy = row_count_strategy
      end

      def run
        prep = prepare!
        return prep if prep

        sql = "REFRESH MATERIALIZED VIEW #{qualified_rel}"

        conn.execute(sql)

        payload = { view: "#{schema}.#{rel}" }
        payload[:rows_count] = fetch_rows_count if row_count_strategy.present?

        ok(:updated,
           payload: payload,
           meta: { sql: sql, row_count_strategy: row_count_strategy })
      rescue StandardError => e
        error_response(e, meta: {
                         sql: sql,
                         backtrace: Array(e.backtrace),
                         row_count_strategy: row_count_strategy
                       }, payload: { view: "#{schema}.#{rel}" })
      end

      # ────────────────────────────────────────────────────────────────
      # internal
      # ────────────────────────────────────────────────────────────────

      def prepare!
        return err("Invalid view name format: #{definition.name.inspect}") unless valid_name?
        return err("Materialized view #{schema}.#{rel} does not exist") unless view_exists?

        nil
      end

      # ────────────────────────────────────────────────────────────────
      # helpers: validation / schema / pg introspection
      # ────────────────────────────────────────────────────────────────

      def valid_name?
        /\A[a-zA-Z_][a-zA-Z0-9_]*\z/.match?(definition.name.to_s)
      end

      # ────────────────────────────────────────────────────────────────
      # rows counting
      # ────────────────────────────────────────────────────────────────

      def fetch_rows_count
        case row_count_strategy
        when :estimated then estimated_rows_count
        when :exact     then exact_rows_count
        end
      end

      # Fast/approx via pg_class.reltuples (updated by ANALYZE/maintenance).
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

      # Accurate but potentially heavy for big views.
      def exact_rows_count
        conn.select_value("SELECT COUNT(*) FROM #{qualified_rel}").to_i
      end
    end
  end
end
