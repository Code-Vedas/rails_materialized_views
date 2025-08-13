# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

module MatViews
  module Services
    # CreateView is a service that handles the creation of materialized views.
    class CreateView < BaseService
      attr_reader :force

      def initialize(definition, force: false)
        super(definition)
        @force = !!force
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
        index_info = ensure_unique_index_if_needed

        ok(:created, payload: { view: qualified_rel, **index_info })
      rescue StandardError => e
        error_response(e, payload: { view: qualified_rel },
                          meta: { sql: sql,
                                  force: force })
      end

      # ────────────────────────────────────────────────────────────────
      # internal
      # ────────────────────────────────────────────────────────────────

      def prepare!
        return err("Invalid view name format: #{definition.name.inspect}") unless valid_name?
        return err('SQL must start with SELECT') unless valid_sql?
        return err('refresh_strategy=concurrent requires unique_index_columns (non-empty)') if strategy == 'concurrent' && cols.empty?

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
        return { created_indexes: [] } unless strategy == 'concurrent'

        # Name like: public_mvname_uniq_col1_col2
        idx_name = [schema, rel, 'uniq', *cols].join('_')

        concurrently = pg_idle?
        conn.execute(<<~SQL)
          CREATE UNIQUE INDEX #{'CONCURRENTLY ' if concurrently}#{quote_table_name(idx_name)}
          ON #{qualified_rel} (#{cols.map { |c| quote_column_name(c) }.join(', ')})
        SQL
        { created_indexes: [idx_name] }
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
    end
  end
end
