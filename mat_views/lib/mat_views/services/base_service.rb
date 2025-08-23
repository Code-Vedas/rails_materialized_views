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
    # {MatViews::Services::RegularRefresh}) should inherit from this class.
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
      ##
      # @return [MatViews::MatViewDefinition] The target materialized view definition.
      attr_reader :definition

      ##
      # @param definition [MatViews::MatViewDefinition]
      def initialize(definition)
        @definition = definition
      end

      private

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
        candidates = raw_path.split(',').filter_map { |t| resolve_schema_token(t.strip) }
        candidates << 'public' unless candidates.include?('public')
        candidates.find { |s| schema_exists?(s) } || 'public'
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
      # @param status [Symbol] e.g., `:ok`, `:created`, `:updated`, `:noop`
      # @param payload [Hash] optional payload
      # @param meta [Hash] optional metadata
      # @return [MatViews::ServiceResponse]
      #
      def ok(status, payload: {}, meta: {})
        MatViews::ServiceResponse.new(status: status, payload: payload, meta: meta)
      end

      ##
      # Build an error response with a message.
      #
      # @api private
      # @param msg [String]
      # @return [MatViews::ServiceResponse]
      #
      def err(msg)
        MatViews::ServiceResponse.new(status: :error, error: msg)
      end

      ##
      # Build an error response from an exception, including backtrace.
      #
      # @api private
      # @param exception [Exception]
      # @param payload [Hash]
      # @param meta [Hash]
      # @return [MatViews::ServiceResponse]
      #
      def error_response(exception, payload: {}, meta: {})
        MatViews::ServiceResponse.new(
          status: :error,
          error: "#{exception.class}: #{exception.message}",
          payload: payload,
          meta: { backtrace: Array(exception.backtrace), **meta }
        )
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
        status = rc.respond_to?(:transaction_status) ? rc.transaction_status : nil
        # Only use CONCURRENTLY outside any tx/savepoint.
        status.nil? || status == PG::PQTRANS_IDLE
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
    end
  end
end
