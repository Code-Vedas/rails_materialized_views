# frozen_string_literal: true

module MatViews
  module Services
    # CreateView is a service that handles the creation of materialized views.
    class CreateView
      attr_reader :definition, :force, :conn, :schema

      def self.call(definition, force: false)
        new(definition, force: force).run
      end

      def initialize(definition, force: false)
        @definition = definition
        @force      = !!force
      end

      def run
        prep = prepare!
        return prep if prep # error response

        # If exists, either noop or drop+recreate
        existed = handle_existing!
        return existed if existed.is_a?(MatViews::ServiceResponse)

        # Always create WITH DATA for a fresh view
        create_with_data

        # For concurrent strategy, ensure the unique index so future
        # REFRESH MATERIALIZED VIEW CONCURRENTLY is allowed.
        created_indexes = ensure_unique_index_if_needed

        ok(view: qualified_rel, created_indexes: created_indexes)
      rescue StandardError => e
        error_response(e)
      end

      # ────────────────────────────────────────────────────────────────
      # internal
      # ────────────────────────────────────────────────────────────────

      def prepare!
        return err("Invalid view name format: #{definition.name.inspect}") unless valid_name?
        return err('SQL must start with SELECT') unless valid_sql?
        return err('refresh_strategy=concurrent requires unique_index_columns (non-empty)') if strategy == 'concurrent' && cols.empty?

        @conn     = ActiveRecord::Base.connection
        @schema   = first_existing_schema
        nil
      end

      def handle_existing!
        return nil unless view_exists?

        return MatViews::ServiceResponse.new(status: :noop) unless force

        drop_view
        nil
      end

      def create_with_data
        conn.execute(<<~SQL)
          CREATE MATERIALIZED VIEW #{qualified_rel} AS
          #{sql}
          WITH DATA
        SQL
      end

      def ensure_unique_index_if_needed
        return [] unless strategy == 'concurrent'

        # Name like: public_mvname_uniq_col1_col2
        idx_name = [schema, rel, 'uniq', *cols].join('_')
        return [] if index_exists?(idx_name)

        concurrently = pg_idle?
        conn.execute(<<~SQL)
          CREATE UNIQUE INDEX #{'CONCURRENTLY ' if concurrently}#{quote_ident(idx_name)}
          ON #{qualified_rel} (#{cols.map { |c| quote_ident(c) }.join(', ')})
        SQL
        [idx_name]
      end

      # ────────────────────────────────────────────────────────────────
      # helpers: validation / schema / pg introspection
      # ────────────────────────────────────────────────────────────────

      def valid_name?
        /\A[a-zA-Z_][a-zA-Z0-9_]*\z/.match?(definition.name.to_s)
      end

      def valid_sql?
        definition.sql.to_s.strip.upcase.start_with?('SELECT')
      end

      def qualified_rel
        %(#{quote_ident(schema)}.#{quote_ident(rel)})
      end

      def view_exists?
        conn.select_value(<<~SQL).to_i.positive?
          SELECT COUNT(*)
          FROM pg_matviews
          WHERE schemaname = #{conn.quote(schema)}
            AND matviewname = #{conn.quote(rel)}
        SQL
      end

      def drop_view
        conn.execute(<<~SQL)
          DROP MATERIALIZED VIEW IF EXISTS #{qualified_rel}
        SQL
      end

      def index_exists?(index_name)
        conn.select_value(<<~SQL).to_i.positive?
          SELECT COUNT(*)
          FROM pg_indexes
          WHERE schemaname = #{conn.quote(schema)}
            AND tablename  = #{conn.quote(rel)}
            AND indexname  = #{conn.quote(index_name)}
        SQL
      end

      def first_existing_schema
        raw_path   = conn.schema_search_path.presence || 'public'
        candidates = raw_path.split(',').filter_map { |t| resolve_schema_token(t.strip) }
        candidates << 'public' unless candidates.include?('public')
        candidates.find { |s| schema_exists?(s) } || 'public'
      end

      def resolve_schema_token(token)
        cleaned = token.delete_prefix('"').delete_suffix('"')
        return current_user if cleaned == '$user'

        cleaned
      end

      def current_user
        @current_user ||= conn.select_value('SELECT current_user')
      end

      def schema_exists?(name)
        conn.select_value("SELECT to_regnamespace(#{conn.quote(name)}) IS NOT NULL")
      end

      def pg_idle?
        rc = conn.raw_connection
        status = rc.respond_to?(:transaction_status) ? rc.transaction_status : nil
        # Only use CONCURRENTLY outside any tx/savepoint.
        status.nil? || status == PG::PQTRANS_IDLE
      rescue StandardError
        false
      end

      def quote_ident(name)
        %("#{name.to_s.gsub('"', '""')}")
      end

      # ────────────────────────────────────────────────────────────────
      # responses
      # ────────────────────────────────────────────────────────────────

      def ok(payload = {})
        MatViews::ServiceResponse.new(status: :created, payload: payload)
      end

      def err(msg)
        MatViews::ServiceResponse.new(status: :error, error: msg)
      end

      def error_response(exception)
        MatViews::ServiceResponse.new(
          status: :error,
          error: "#{exception.class}: #{exception.message}",
          meta: { backtrace: Array(exception.backtrace) }
        )
      end

      def strategy
        @strategy ||= definition.refresh_strategy.to_s
      end

      def rel
        @rel ||= definition.name.to_s
      end

      def sql
        @sql ||= definition.sql.to_s
      end

      def cols
        @cols ||= Array(definition.unique_index_columns).map(&:to_s).uniq
      end
    end
  end
end
