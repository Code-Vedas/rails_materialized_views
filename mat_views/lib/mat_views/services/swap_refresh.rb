# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

require 'securerandom'

module MatViews
  module Services
    # SwapRefresh rebuilds into a temporary MV and atomically swaps it in.
    # Steps:
    # 1) CREATE MATERIALIZED VIEW <tmp> AS <definition.sql> WITH DATA
    # 2) (txn) RENAME original -> <old>, RENAME tmp -> original, DROP <old>
    # 3) Recreate declared indexes/privileges as needed
    class SwapRefresh < BaseService
      attr_reader :row_count_strategy

      def initialize(definition, row_count_strategy: :estimated)
        super(definition)
        @row_count_strategy = row_count_strategy
      end

      def run
        prep = prepare!
        return prep if prep

        create_sql = %(CREATE MATERIALIZED VIEW #{q_tmp} AS #{definition.sql} WITH DATA)
        steps = [create_sql]
        conn.execute(create_sql)

        steps.concat(swap_index)

        payload = { view: "#{schema}.#{rel}" }
        payload[:rows_count] = fetch_rows_count if row_count_strategy.present?

        ok(:updated,
           payload: payload,
           meta: { steps: steps, row_count_strategy: row_count_strategy, swap: true })
      rescue StandardError => e
        error_response(e,
                       meta: { steps: steps, backtrace: Array(e.backtrace), row_count_strategy: row_count_strategy, swap: true },
                       payload: { view: "#{schema}.#{rel}" })
      end

      # ────────────────────────────────────────────────────────────────
      # internal
      # ────────────────────────────────────────────────────────────────

      def prepare!
        return err("Invalid view name format: #{definition.name.inspect}") unless valid_name?
        return err("Materialized view #{schema}.#{rel} does not exist") unless view_exists?

        nil
      end

      def swap_index
        steps = []
        conn.transaction do
          rename_orig_sql = %(ALTER MATERIALIZED VIEW #{qualified_rel} RENAME TO #{conn.quote_column_name(old_rel)})
          steps << rename_orig_sql
          conn.execute(rename_orig_sql)

          rename_tmp_sql = %(ALTER MATERIALIZED VIEW #{q_tmp} RENAME TO #{conn.quote_column_name(rel)})
          steps << rename_tmp_sql
          conn.execute(rename_tmp_sql)

          drop_old_sql = %(DROP MATERIALIZED VIEW #{q_old})
          steps << drop_old_sql
          conn.execute(drop_old_sql)

          recreate_declared_unique_indexes!(schema:, rel:, steps:)
        end
        steps
      end

      def q_tmp
        @q_tmp ||= conn.quote_table_name("#{schema}.#{tmp_rel}")
      end

      def q_old
        @q_old ||= conn.quote_table_name("#{schema}.#{old_rel}")
      end

      def tmp_rel
        @tmp_rel ||= "#{rel}__tmp_#{SecureRandom.hex(4)}"
      end

      def old_rel
        @old_rel ||= "#{rel}__old_#{SecureRandom.hex(4)}"
      end

      # Keep consistency with Regular/Concurrent services
      def valid_name?
        /\A[a-zA-Z_][a-zA-Z0-9_]*\z/.match?(definition.name.to_s)
      end

      def resolve_schema_token(token)
        cleaned = token.delete_prefix('"').delete_suffix('"')
        return current_user if cleaned == '$user'

        cleaned
      end

      # Create unique index(es) described by definition.unique_index_columns
      # Accepts single or multiple columns (array of strings).
      def recreate_declared_unique_indexes!(schema:, rel:, steps:)
        cols = Array(definition.unique_index_columns).map(&:to_s).reject(&:empty?)
        return if cols.empty?

        quoted_cols = cols.map { |c| conn.quote_column_name(c) }.join(', ')
        idx_name    = conn.quote_column_name("#{rel}_uniq_#{cols.join('_')}")
        q_rel       = conn.quote_table_name("#{schema}.#{rel}")

        sql = %(CREATE UNIQUE INDEX #{idx_name} ON #{q_rel} (#{quoted_cols}))
        steps << sql
        conn.execute(sql)
      end

      # ────────────────────────────────────────────────────────────────
      # rows counting (same as your other services)
      # ────────────────────────────────────────────────────────────────

      def fetch_rows_count
        case row_count_strategy
        when :estimated then estimated_rows_count
        when :exact     then exact_rows_count
        end
      end

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

      def exact_rows_count
        conn.select_value("SELECT COUNT(*) FROM #{qualified_rel}").to_i
      end
    end
  end
end
