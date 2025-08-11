# frozen_string_literal: true

module MatViews
  module Services
    # RegularRefresh executes a standard (locking) REFRESH MATERIALIZED VIEW.
    # It is the safest option for simple / low-frequency updates.
    class RegularRefresh
      attr_reader :definition, :row_count_strategy

      # row_count_strategy: :estimated | :exact | nil
      def initialize(definition, row_count_strategy: :estimated)
        @definition = definition
        @row_count_strategy = row_count_strategy
      end

      def run
        prep = prepare!
        return prep if prep

        sql = "REFRESH MATERIALIZED VIEW #{qualified_rel}"

        conn.execute(sql)

        payload = { view: "#{schema}.#{rel}" }
        payload[:rows_count] = fetch_rows_count if row_count_strategy.present?

        MatViews::ServiceResponse.new(status: :updated,
                                      payload: payload,
                                      meta: { sql: sql, row_count_strategy: row_count_strategy })
      rescue StandardError => e
        MatViews::ServiceResponse.new(status: :error,
                                      error: "#{e.class}: #{e.message}",
                                      payload: { view: "#{schema}.#{rel}" },
                                      meta: {
                                        sql: sql,
                                        backtrace: Array(e.backtrace),
                                        row_count_strategy: row_count_strategy
                                      })
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

      def first_existing_schema
        raw_path   = conn.schema_search_path.presence || 'public'
        candidates = raw_path.split(',').filter_map { |t| resolve_schema_token(t.strip) }
        candidates << 'public' unless Set.new(candidates).include?('public')
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

      def quote_ident(name)
        %("#{name.to_s.gsub('"', '""')}")
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

      # ────────────────────────────────────────────────────────────────
      # responses
      # ────────────────────────────────────────────────────────────────

      def err(msg)
        MatViews::ServiceResponse.new(status: :error, error: msg)
      end

      # ────────────────────────────────────────────────────────────────
      # memoized accessors
      # ────────────────────────────────────────────────────────────────

      def conn
        @conn ||= ActiveRecord::Base.connection
      end

      def schema
        @schema ||= first_existing_schema
      end

      def rel
        @rel ||= definition.name.to_s
      end
    end
  end
end
