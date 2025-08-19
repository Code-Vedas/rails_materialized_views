# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

require 'securerandom'

module MatViews
  module Services
    ##
    # Service that performs a **swap-style refresh** of a materialized view.
    #
    # Instead of locking the existing view, this strategy builds a new
    # temporary materialized view and atomically swaps it in. This approach
    # minimizes downtime and allows for safer rebuilds of large views.
    #
    # Steps:
    # 1. Create a temporary MV from the provided SQL.
    # 2. In a transaction: rename original → old, tmp → original, drop old.
    # 3. Recreate declared unique indexes (if any).
    #
    # Supports optional row count strategies:
    # - `:estimated` → approximate, using `pg_class.reltuples`
    # - `:exact` → accurate, using `COUNT(*)`
    # - `nil` → skip row count
    #
    # @return [MatViews::ServiceResponse]
    #
    # @example
    #   svc = MatViews::Services::SwapRefresh.new(defn, row_count_strategy: :exact)
    #   svc.run
    #
    class SwapRefresh < BaseService
      ##
      # Row count strategy (`:estimated`, `:exact`, `nil`).
      #
      # @return [Symbol, nil]
      attr_reader :row_count_strategy

      ##
      # @param definition [MatViews::MatViewDefinition]
      # @param row_count_strategy [Symbol, nil]
      def initialize(definition, row_count_strategy: :estimated)
        super(definition)
        @row_count_strategy = row_count_strategy
      end

      ##
      # Execute the swap refresh.
      #
      # @return [MatViews::ServiceResponse]
      def run
        prep = prepare!
        return prep if prep

        create_sql = %(CREATE MATERIALIZED VIEW #{q_tmp} AS #{definition.sql} WITH DATA)
        steps = [create_sql]
        conn.execute(create_sql)

        steps.concat(swap_index)

        payload = { view: "#{schema}.#{rel}" }
        payload[:rows_count] = fetch_rows_count if row_count_strategy.present?

        ok(:updated, payload: payload, meta: { steps: steps, row_count_strategy: row_count_strategy, swap: true })
      rescue StandardError => e
        error_response(e,
                       meta: {
                         steps: steps,
                         backtrace: Array(e.backtrace),
                         row_count_strategy: row_count_strategy,
                         swap: true
                       },
                       payload: { view: "#{schema}.#{rel}" })
      end

      private

      # ────────────────────────────────────────────────────────────────
      # internal
      # ────────────────────────────────────────────────────────────────

      ##
      # Ensure name validity and existence of original view.
      #
      # @api private
      # @return [MatViews::ServiceResponse, nil]
      def prepare!
        return err("Invalid view name format: #{definition.name.inspect}") unless valid_name?
        return err("Materialized view #{schema}.#{rel} does not exist") unless view_exists?

        nil
      end

      ##
      # Perform rename/drop/index recreation in a transaction.
      #
      # @api private
      # @return [Array<String>] SQL steps executed
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

      ##
      # Quote the temporary materialized view name.
      #
      # @api private
      # @return [String] quoted temporary view name
      def q_tmp
        @q_tmp ||= conn.quote_table_name("#{schema}.#{tmp_rel}")
      end

      ##
      # Quote the original materialized view name.
      #
      # @api private
      # @return [String] quoted original view name
      def q_old
        @q_old ||= conn.quote_table_name("#{schema}.#{old_rel}")
      end

      ##
      # Fully-qualified, safely-quoted temporary relation name.
      #
      # @api private
      # @return [String]
      def tmp_rel
        @tmp_rel ||= "#{rel}__tmp_#{SecureRandom.hex(4)}"
      end

      ##
      # Fully-qualified, safely-quoted old relation name.
      #
      # @api private
      # @return [String]
      def old_rel
        @old_rel ||= "#{rel}__old_#{SecureRandom.hex(4)}"
      end

      ##
      # Validate that the view name is a sane PostgreSQL identifier.
      #
      # @api private
      # @return [Boolean]
      def valid_name?
        /\A[a-zA-Z_][a-zA-Z0-9_]*\z/.match?(definition.name.to_s)
      end

      ##
      # Recreate declared unique indexes on the swapped-in view.
      #
      # @api private
      # @param schema [String]
      # @param rel [String]
      # @param steps [Array<String>] collected SQL
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
      # rows counting
      # ────────────────────────────────────────────────────────────────

      ##
      # Fetch the row count based on the configured strategy.
      #
      # @api private
      # @return [Integer, nil]
      def fetch_rows_count
        case row_count_strategy
        when :estimated then estimated_rows_count
        when :exact     then exact_rows_count
        end
      end

      ##
      # Approximate row count via `pg_class.reltuples`.
      #
      # @api private
      # @return [Integer]
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
      # Accurate row count via `COUNT(*)`.
      #
      # @api private
      # @return [Integer]
      def exact_rows_count
        conn.select_value("SELECT COUNT(*) FROM #{qualified_rel}").to_i
      end
    end
  end
end
