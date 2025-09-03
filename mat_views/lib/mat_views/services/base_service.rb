# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

module MatViews
  module Services
    ##
    # Base class for service objects that operate on PostgreSQL materialized
    # views (create/refresh/delete, schema discovery, quoting, and common
    # response helpers).
    #
    # Concrete services (e.g., {MatViews::Services::CreateView},
    # {MatViews::Services::Services::RegularRefresh}) should inherit from this class.
    #
    # @abstract
    #
    # @example Subclassing BaseService
    #   class MyService < MatViews::Services::BaseService
    #     def run
    #       return err("missing view") unless view_exists?
    #       # perform work...
    #       ok(:updated, payload: { view: "#{schema}.#{rel}" })
    #     rescue => e
    #       error_response(e, meta: { op: "my_service" })
    #     end
    #   end
    #
    class BaseService
      ALLOWED_ROW_STRATEGIES = %i[none estimated exact].freeze
      DEFAULT_ROW_STRATEGY = :estimated
      DEFAULT_NIL_STRATEGY = :none

      ##
      # @return [MatViews::MatViewDefinition] The target materialized view definition.
      attr_reader :definition

      ##
      # Row count strategy (`:estimated`, `:exact`, `nil`).
      #
      # @return [Symbol, nil]
      attr_reader :row_count_strategy

      ##
      # request hash to be returned in service response
      # @return [Hash]
      attr_accessor :request

      ##
      # response hash to be returned in service response
      # @return [Hash]
      attr_accessor :response

      ##
      # @param definition [MatViews::MatViewDefinition]
      # @param row_count_strategy [Symbol, nil] one of `:estimated`, `:exact`, or `nil` (default: `:estimated`)
      #
      def initialize(definition, row_count_strategy: DEFAULT_ROW_STRATEGY)
        @definition = definition
        @row_count_strategy = extract_row_strategy(row_count_strategy)
        @request = {}
        @response = {}
      end

      ##
      # Execute the service operation.
      #
      # Calls {#assign_request}, {#prepare} and {#_run} in order.
      #
      # Concrete subclasses must implement these methods.
      #
      # @return [MatViews::ServiceResponse]
      # @raise [NotImplementedError] if not implemented in subclass
      def run
        assign_request
        prepare
        _run
      rescue StandardError => e
        error_response(e)
      end

      private

      ##
      # Assign the request parameters.
      # Called by {#run} before {#prepare}.
      #
      # Must be implemented in concrete subclasses.
      #
      # @api private
      # @return [void]
      # @raise [NotImplementedError] if not implemented in subclass
      #
      def assign_request
        raise NotImplementedError, "Must implement #{self.class}##{__method__}"
      end

      ##
      # Perform pre-flight checks.
      # Called by {#run} after {#assign_request}.
      #
      # Must be implemented in concrete subclasses.
      #
      # @api private
      # @return [nil] on success
      # @raise [StandardError] on failure
      # @raise [NotImplementedError] if not implemented in subclass
      #
      def prepare
        raise NotImplementedError, "Must implement #{self.class}##{__method__}"
      end

      ##
      # Execute the service operation.
      # Called by {#run} after {#prepare}.
      #
      # Must be implemented in concrete subclasses.
      #
      # @api private
      # @return [MatViews::ServiceResponse]
      # @raise [NotImplementedError] if not implemented in subclass
      #
      def _run
        raise NotImplementedError, "Must implement #{self.class}##{__method__}"
      end

      def extract_row_strategy(value)
        ALLOWED_ROW_STRATEGIES.find { |strategy| strategy == value } || DEFAULT_NIL_STRATEGY
      end

      # ────────────────────────────────────────────────────────────────
      # Schema / resolution helpers
      # ────────────────────────────────────────────────────────────────

      ##
      # Resolve the first existing schema from `schema_search_path`,
      # falling back to `"public"` if none are valid.
      #
      # Supports `$user`, quoted tokens, and ignores non-existent schemas.
      #
      # @api private
      # @return [String] a valid schema name
      #
      def first_existing_schema
        raw_path   = conn.schema_search_path.presence || 'public'
        candidates = raw_path.split(',').filter_map { |token| resolve_schema_token(token.strip) }
        candidates << 'public' unless candidates.include?('public')
        candidates.find { |schema_str| schema_exists?(schema_str) } || 'public'
      end

      ##
      # Normalize a schema token:
      # - strip surrounding quotes
      # - expand `$user` to the current database user
      #
      # @api private
      # @param token [String]
      # @return [String]
      #
      def resolve_schema_token(token)
        cleaned = token.delete_prefix('"').delete_suffix('"')
        return current_user if cleaned == '$user'

        cleaned
      end

      ##
      # @api private
      # @return [String] current PostgreSQL user
      def current_user
        @current_user ||= conn.select_value('SELECT current_user')
      end

      ##
      # Check whether a schema exists.
      #
      # @api private
      # @param name [String] schema name
      # @return [Boolean]
      #
      def schema_exists?(name)
        conn.select_value("SELECT to_regnamespace(#{conn.quote(name)}) IS NOT NULL")
      end

      # ────────────────────────────────────────────────────────────────
      # View / relation helpers
      # ────────────────────────────────────────────────────────────────

      ##
      # Whether the materialized view exists for the resolved `schema` and `rel`.
      #
      # @api private
      # @return [Boolean]
      #
      def view_exists?
        conn.select_value(<<~SQL).to_i.positive?
          SELECT COUNT(*)
          FROM pg_matviews
          WHERE schemaname = #{conn.quote(schema)}
            AND matviewname = #{conn.quote(rel)}
        SQL
      end

      ##
      # Fully-qualified, safely-quoted relation name, e.g. `"public"."mv_users"`.
      #
      # @api private
      # @return [String]
      #
      def qualified_rel
        %(#{quote_table_name(schema)}.#{quote_table_name(rel)})
      end

      ##
      # Drop the materialized view if it exists (idempotent).
      #
      # @api private
      # @return [void]
      #
      def drop_view
        conn.execute(<<~SQL)
          DROP MATERIALIZED VIEW IF EXISTS #{qualified_rel}
        SQL
      end

      ##
      # Refresh strategy from the definition (stringified).
      #
      # @api private
      # @return [String] one of `"regular"`, `"concurrent"`, `"swap"` (or custom)
      #
      def strategy
        @strategy ||= definition.refresh_strategy.to_s
      end

      ##
      # Unqualified relation (matview) name from the definition.
      #
      # @api private
      # @return [String]
      #
      def rel
        @rel ||= definition.name.to_s
      end

      ##
      # SQL `SELECT …` for the materialization.
      #
      # @api private
      # @return [String]
      #
      def sql
        @sql ||= definition.sql.to_s
      end

      ##
      # Unique index column list (normalized to strings, unique).
      #
      # @api private
      # @return [Array<String>]
      #
      def cols
        @cols ||= Array(definition.unique_index_columns).map(&:to_s).uniq
      end

      ##
      # ActiveRecord connection.
      #
      # @api private
      # @return [ActiveRecord::ConnectionAdapters::AbstractAdapter]
      #
      def conn
        @conn ||= ActiveRecord::Base.connection
      end

      ##
      # Resolved, existing schema for this operation.
      #
      # @api private
      # @return [String]
      #
      def schema
        @schema ||= first_existing_schema
      end

      # ────────────────────────────────────────────────────────────────
      # Response helpers
      # ────────────────────────────────────────────────────────────────

      ##
      # Build a success response.
      #
      # @api private
      # @param status [Symbol] e.g., `:ok`, `:created`, `:updated`, `:skipped`, `:deleted`
      # @return [MatViews::ServiceResponse]
      #
      def ok(status)
        MatViews::ServiceResponse.new(status:, request:, response:)
      end

      ##
      # Raise a StandardError with the given message.
      #
      # @api private
      # @param msg [String]
      # @return [void]
      # @raise [StandardError] with `msg`
      #
      def raise_err(msg)
        raise StandardError, msg
      end

      ##
      # Build an error response from an exception, including backtrace.
      #
      # @api private
      # @param error [Exception]
      # @return [MatViews::ServiceResponse]
      #
      def error_response(error)
        MatViews::ServiceResponse.new(status: :error, error:, request:, response:)
      end

      # ────────────────────────────────────────────────────────────────
      # Quoting / environment helpers
      # ────────────────────────────────────────────────────────────────

      ##
      # Quote a column name for SQL.
      #
      # @api private
      # @param name [String, Symbol]
      # @return [String] quoted column name
      #
      def quote_column_name(name)
        conn.quote_column_name(name)
      end

      ##
      # Quote a table/relation name for SQL.
      #
      # @api private
      # @param name [String, Symbol]
      # @return [String] quoted relation name
      #
      def quote_table_name(name)
        conn.quote_table_name(name)
      end

      ##
      # Whether the underlying PG connection is idle (no active tx/savepoint).
      #
      # Used to guard `CONCURRENTLY` operations which must run outside a txn.
      #
      # @api private
      # @return [Boolean]
      #
      def pg_idle?
        rc = conn.raw_connection
        return true unless rc.respond_to?(:transaction_status)

        # Only use CONCURRENTLY outside any tx/savepoint.
        rc.transaction_status == PG::PQTRANS_IDLE
      rescue StandardError
        false
      end

      ##
      # Validate SQL starts with SELECT.
      #
      # @api private
      # @return [Boolean]
      #
      def valid_sql?
        definition.sql.to_s.strip.upcase.start_with?('SELECT')
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
      # rows counting
      # ────────────────────────────────────────────────────────────────

      ##
      # Compute row count based on the configured strategy.
      #
      # @api private
      # @return [Integer, nil]
      #
      def fetch_rows_count
        case row_count_strategy
        when :estimated then estimated_rows_count
        when :exact     then exact_rows_count
        else
          -1
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
