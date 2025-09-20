# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

module MatViews
  module Services
    ##
    # Service responsible for creating PostgreSQL materialised views.
    #
    # The service validates the view definition, handles existence checks,
    # executes `CREATE MATERIALIZED VIEW ... WITH DATA`, and, when the
    # refresh strategy is `:concurrent`, ensures a supporting UNIQUE index.
    #
    # Options:
    # - `force:` (Boolean, default: false) → drop and recreate if the view already exists
    # - `row_count_strategy:` (Symbol, default: :none) → one of `:estimated`, `:exact`, or `:none or nil` to control row count reporting
    #
    # Returns a {MatViews::ServiceResponse}
    #
    # @see MatViews::Services::RegularRefresh
    # @see MatViews::Services::ConcurrentRefresh
    #
    # @example Create a new matview (no force)
    #   svc = MatViews::Services::CreateView.new(defn, **options)
    #   response = svc.call
    #   response.status # => :created or :skipped
    #
    # @example Force recreate an existing matview
    #   svc = MatViews::Services::CreateView.new(defn, force: true)
    #   svc.call
    #
    # @example via job, this is the typical usage and will create a run record in the DB
    #   MatViews::Jobs::Adapter.enqueue(MatViews::Services::CreateViewJob, definition.id, **options)
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
      # @param row_count_strategy [Symbol, nil] one of `:estimated`, `:exact`, or `nil` (default: `:estimated`)
      #
      # Supports optional row count strategies:
      # - `:estimated` → approximate, using `pg_class.reltuples`
      # - `:exact` → accurate, using `COUNT(*)`
      # - `nil` → skip row count
      def initialize(definition, force: false, row_count_strategy: :estimated)
        super(definition, row_count_strategy: row_count_strategy)
        @force = force
        # Transactions are disabled if unique_index_columns are present because
        # PostgreSQL does not allow creating a UNIQUE INDEX CONCURRENTLY inside a transaction block.
        # If a unique index is required (for concurrent refresh), we must avoid wrapping the operation in a transaction.
        @use_transaction = definition.unique_index_columns.none?
      end

      private

      ##
      # Execute the create operation.
      #
      # - Validates name, SQL, and concurrent-index requirements.
      # - Handles existing view: skipped (default) or drop+recreate (`force: true`).
      # - Creates the materialised view WITH DATA.
      # - Creates a UNIQUE index if refresh strategy is concurrent.
      #
      # @api private
      #
      # @return [MatViews::ServiceResponse]
      #   - `status: :created or :skipped` on success, with `response` containing:
      #     - `view` - the qualified view name
      #     - `row_count_before` - if requested and available
      #     - `row_count_after` - if requested and available
      #   - `status: :error` with `error` on failure, with `error` containing:
      #     - serlialized exception class, message, and backtrace in a hash
      def _run
        sql = create_with_data_sql
        self.response = { view: "#{schema}.#{rel}", sql: [sql] }
        # If exists, either skipped or drop+recreate
        existed = handle_existing
        return existed if existed.is_a?(MatViews::ServiceResponse)

        response[:row_count_before] = UNKNOWN_ROW_COUNT
        conn.execute(sql)
        response[:row_count_after] = fetch_rows_count

        # For concurrent strategy, ensure the unique index so future
        # REFRESH MATERIALIZED VIEW CONCURRENTLY is allowed.
        response.merge!(ensure_unique_index_if_needed)

        ok(:created)
      end

      ##
      # Validation step (invoked by BaseService#call before execution).
      # Empty for this service as no other preparation is needed.
      #
      # @api private
      #
      # @return [void]
      #
      def prepare; end

      ##
      # Assign the request parameters.
      # Called by {#call} before {#prepare}.
      #
      # @api private
      # @return [void]
      #
      def assign_request
        self.request = { row_count_strategy: row_count_strategy, force: }
      end

      ##
      # Handle existing matview: return skipped if not forcing, or drop if forcing.
      #
      # @api private
      # @return [MatViews::ServiceResponse, nil]
      #
      def handle_existing
        return nil unless view_exists?

        return ok(:skipped) unless force

        drop_view
        nil
      end

      ##
      # SQL for `CREATE MATERIALIZED VIEW ... WITH DATA`.
      # @api private
      # @return [String]
      #
      def create_with_data_sql
        <<~SQL
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
          ON #{qualified_rel} (#{cols.map { |col| quote_column_name(col) }.join(', ')})
        SQL
        { created_indexes: [idx_name], row_count_before: UNKNOWN_ROW_COUNT, row_count_after: fetch_rows_count }
      end
    end
  end
end
