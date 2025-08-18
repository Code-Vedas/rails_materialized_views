# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

module MatViews
  module Services
    ##
    # Refresh service that runs:
    #
    #   `REFRESH MATERIALIZED VIEW CONCURRENTLY <schema>.<rel>`
    #
    # It keeps the view readable during refresh, but **requires at least one
    # UNIQUE index** on the materialized view (a PostgreSQL constraint).
    # Returns a {MatViews::ServiceResponse}.
    #
    # Row-count reporting is optional and controlled by `row_count_strategy`:
    # - `:estimated` — fast/approx via `pg_class.reltuples`
    # - `:exact` — accurate `COUNT(*)`
    # - `nil` (or any unrecognized value) — skip counting
    #
    # @see MatViews::Services::RegularRefresh
    # @see MatViews::Services::SwapRefresh
    #
    # @example Direct usage
    #   svc = MatViews::Services::ConcurrentRefresh.new(definition, row_count_strategy: :exact)
    #   response = svc.run
    #   response.success? # => true/false
    #
    # @example Via job selection (within RefreshViewJob)
    #   # When definition.refresh_strategy == "concurrent"
    #   MatViews::RefreshViewJob.perform_later(definition.id, :estimated)
    #
    class ConcurrentRefresh < BaseService
      ##
      # Strategy for computing rows count after refresh.
      #
      # @return [Symbol, nil] one of `:estimated`, `:exact`, or `nil`
      attr_reader :row_count_strategy

      ##
      # @param definition [MatViews::MatViewDefinition]
      # @param row_count_strategy [Symbol, nil] `:estimated` (default), `:exact`, or `nil`
      def initialize(definition, row_count_strategy: :estimated)
        super(definition)
        @row_count_strategy = row_count_strategy
      end

      ##
      # Execute the concurrent refresh.
      #
      # Validates name format, existence of the matview, and presence of a UNIQUE index.
      # If validation fails, returns an error {MatViews::ServiceResponse}.
      #
      # @return [MatViews::ServiceResponse]
      #   - `status: :updated` with payload `{ view:, rows_count? }` on success
      #   - `status: :error` with `error` on failure
      #
      # @raise [StandardError] bubbled after being wrapped into {#error_response}
      #
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

      private

      # ────────────────────────────────────────────────────────────────
      # internal
      # ────────────────────────────────────────────────────────────────

      ##
      # Perform pre-flight checks.
      #
      # @api private
      # @return [MatViews::ServiceResponse, nil] error response or `nil` if OK
      #
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

      ##
      # Validate that the view name is a sane PostgreSQL identifier.
      #
      # @api private
      # @return [Boolean]
      #
      def valid_name?
        /\A[a-zA-Z_][a-zA-Z0-9_]*\z/.match?(definition.name.to_s)
      end

      ##
      # Check for any UNIQUE index on the materialized view, required by CONCURRENTLY.
      #
      # @api private
      # @return [Boolean]
      #
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

      ##
      # Compute rows count based on the configured strategy.
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
      # Fast, approximate row count via `pg_class.reltuples`.
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
      # Accurate row count using `COUNT(*)` on the materialized view.
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
