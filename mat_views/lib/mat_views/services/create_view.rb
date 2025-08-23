# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

module MatViews
  module Services
    ##
    # Service responsible for creating PostgreSQL materialized views.
    #
    # The service validates the view definition, handles existence checks,
    # executes `CREATE MATERIALIZED VIEW ... WITH DATA`, and, when the
    # refresh strategy is `:concurrent`, ensures a supporting UNIQUE index.
    #
    # Returns a {MatViews::ServiceResponse}.
    #
    # @see MatViews::Services::RegularRefresh
    # @see MatViews::Services::ConcurrentRefresh
    #
    # @example Create a new matview (no force)
    #   svc = MatViews::Services::CreateView.new(defn)
    #   response = svc.run
    #   response.status # => :created or :noop
    #
    # @example Force recreate an existing matview
    #   svc = MatViews::Services::CreateView.new(defn, force: true)
    #   svc.run
    #
    class CreateView < BaseService
      ##
      # Whether to force recreation (drop+create if exists).
      #
      # @return [Boolean]
      attr_reader :force

      ##
      # @param definition [MatViews::MatViewDefinition]
      # @param force [Boolean] Whether to drop+recreate an existing matview.
      def initialize(definition, force: false)
        super(definition)
        @force = !!force
      end

      ##
      # Execute the create operation.
      #
      # - Validates name, SQL, and concurrent-index requirements.
      # - Handles existing view: noop (default) or drop+recreate (`force: true`).
      # - Creates the materialized view WITH DATA.
      # - Creates a UNIQUE index if refresh strategy is concurrent.
      #
      # @return [MatViews::ServiceResponse]
      #   - `:created` on success (payload includes `view` and `created_indexes`)
      #   - `:noop` if the view already exists and `force: false`
      #   - `:error` if validation or execution fails
      #
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
        error_response(
          e,
          payload: { view: qualified_rel },
          meta: { sql: sql, force: force }
        )
      end

      private

      # ────────────────────────────────────────────────────────────────
      # internal
      # ────────────────────────────────────────────────────────────────

      ##
      # Validate name, SQL, and concurrent strategy requirements.
      #
      # @api private
      # @return [MatViews::ServiceResponse, nil] error response or nil if OK
      #
      def prepare!
        return err("Invalid view name format: #{definition.name.inspect}") unless valid_name?
        return err('SQL must start with SELECT') unless valid_sql?
        return err('refresh_strategy=concurrent requires unique_index_columns (non-empty)') if strategy == 'concurrent' && cols.empty?

        nil
      end

      ##
      # Handle existing matview: return noop if not forcing, or drop if forcing.
      #
      # @api private
      # @return [MatViews::ServiceResponse, nil]
      #
      def handle_existing!
        return nil unless view_exists?

        return MatViews::ServiceResponse.new(status: :noop) unless force

        drop_view
        nil
      end

      ##
      # Execute the CREATE MATERIALIZED VIEW WITH DATA statement.
      #
      # @api private
      # @return [void]
      #
      def create_with_data
        conn.execute(<<~SQL)
          CREATE MATERIALIZED VIEW #{qualified_rel} AS
          #{sql}
          WITH DATA
        SQL
      end

      ##
      # Ensure a UNIQUE index if refresh strategy is concurrent.
      #
      # Builds an index name like `public_mvname_uniq_col1_col2`.
      # Creates it concurrently if the PG connection is idle.
      #
      # @api private
      # @return [Hash] `{ created_indexes: [String] }` or empty array if not needed
      #
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
    end
  end
end
