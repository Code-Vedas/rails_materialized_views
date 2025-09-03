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
    #
    # Options:
    # - `row_count_strategy:` (Symbol, default: :none) → one of `:estimated`, `:exact`, or `:none or nil` to control row count reporting
    #
    # Returns a {MatViews::ServiceResponse}
    #
    # @see MatViews::Services::RegularRefresh
    # @see MatViews::Services::SwapRefresh
    #
    # @example Direct usage
    #   svc = MatViews::Services::ConcurrentRefresh.new(definition, **options)
    #   response = svc.run
    #   response.success? # => true/false
    #
    # @example via job, this is the typical usage and will create a run record in the DB
    #   When definition.refresh_strategy == "concurrent"
    #   MatViews::Jobs::Adapter.enqueue(MatViews::Services::RefreshViewJob, definition.id, **options)
    #
    class ConcurrentRefresh < BaseService
      private

      ##
      # Execute the concurrent refresh.
      #
      # Validates name format, existence of the matview, and presence of a UNIQUE index.
      # If validation fails, returns an error {MatViews::ServiceResponse}.
      #
      # @return [MatViews::ServiceResponse]
      #   - `status: :updated` on success, with `response` containing:
      #     - `view` - the qualified view name
      #     - `row_count_before` - if requested and available
      #     - `row_count_after` - if requested and available
      #   - `status: :error` with `error` on failure, with `error` containing:
      #     - serlialized exception class, message, and backtrace in a hash
      def _run
        sql = "REFRESH MATERIALIZED VIEW CONCURRENTLY #{qualified_rel}"
        self.response = { view: "#{schema}.#{rel}", sql: [sql] }

        response[:row_count_before] = fetch_rows_count
        conn.execute(sql)
        response[:row_count_after] = fetch_rows_count

        ok(:updated)
      end

      ##
      # Assign the request parameters.
      # Called by {#run} before {#prepare}.
      # Sets `concurrent: true` in the request hash.
      #
      # @api private
      # @return [void]
      #
      def assign_request
        self.request = { row_count_strategy: row_count_strategy, concurrent: true }
      end

      ##
      # Perform pre-flight checks.
      # Called by {#run} after {#assign_request}.
      #
      # @api private
      # @return [nil] on success
      # @raise [StandardError] on failure
      #
      def prepare
        raise_err("Invalid view name format: #{definition.name.inspect}") unless valid_name?
        raise_err("Materialized view #{schema}.#{rel} does not exist") unless view_exists?
        raise_err("Materialized view #{schema}.#{rel} must have a unique index for concurrent refresh") unless unique_index_exists?

        nil
      end
    end
  end
end
