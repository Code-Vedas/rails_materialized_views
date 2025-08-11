# frozen_string_literal: true

module MatViews
  module Services
    # BaseService is a service that handles the creation of materialized views.
    class BaseService
      attr_reader :definition

      def initialize(definition)
        @definition = definition
      end

      private

      def first_existing_schema
        raw_path   = conn.schema_search_path.presence || 'public'
        candidates = raw_path.split(',').filter_map { |t| resolve_schema_token(t.strip) }
        candidates << 'public' unless candidates.include?('public')
        candidates.find { |s| schema_exists?(s) } || 'public'
      end

      def current_user
        @current_user ||= conn.select_value('SELECT current_user')
      end

      def schema_exists?(name)
        conn.select_value("SELECT to_regnamespace(#{conn.quote(name)}) IS NOT NULL")
      end

      def view_exists?
        conn.select_value(<<~SQL).to_i.positive?
          SELECT COUNT(*)
          FROM pg_matviews
          WHERE schemaname = #{conn.quote(schema)}
            AND matviewname = #{conn.quote(rel)}
        SQL
      end

      def qualified_rel
        %(#{quote_column_name(schema)}.#{quote_table_name(rel)})
      end

      def drop_view
        conn.execute(<<~SQL)
          DROP MATERIALIZED VIEW IF EXISTS #{qualified_rel}
        SQL
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

      def conn
        @conn ||= ActiveRecord::Base.connection
      end

      def schema
        @schema ||= first_existing_schema
      end

      # ────────────────────────────────────────────────────────────────
      # responses
      # ────────────────────────────────────────────────────────────────

      def ok(status, payload: {}, meta: {})
        MatViews::ServiceResponse.new(status: status, payload: payload, meta: meta)
      end

      def err(msg)
        MatViews::ServiceResponse.new(status: :error, error: msg)
      end

      def error_response(exception, payload: {}, meta: {})
        MatViews::ServiceResponse.new(
          status: :error,
          error: "#{exception.class}: #{exception.message}",
          payload: payload,
          meta: { backtrace: Array(exception.backtrace), **meta }
        )
      end

      def quote_column_name(name)
        conn.quote_column_name(name)
      end

      def quote_table_name(name)
        conn.quote_table_name(name)
      end

      def pg_idle?
        rc = conn.raw_connection
        status = rc.respond_to?(:transaction_status) ? rc.transaction_status : nil
        # Only use CONCURRENTLY outside any tx/savepoint.
        status.nil? || status == PG::PQTRANS_IDLE
      rescue StandardError
        false
      end
    end
  end
end
