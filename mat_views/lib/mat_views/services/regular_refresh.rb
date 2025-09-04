# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

module MatViews
  module Services
    ##
    # Service that executes a standard (locking) `REFRESH MATERIALIZED VIEW`.
    #
    # This is the safest option for simple or low-frequency updates where
    # blocking reads during refresh is acceptable.
    #
    # Options:
    # - `row_count_strategy:` (Symbol, default: :none) → one of `:estimated`, `:exact`, or `:none or nil` to control row count reporting
    #
    # Returns a {MatViews::ServiceResponse}
    #
    # @see MatViews::Services::ConcurrentRefresh
    # @see MatViews::Services::SwapRefresh
    #
    # @example Direct usage
    #   svc = MatViews::Services::RegularRefresh.new(definition, **options)
    #   response = svc.call
    #   response.success? # => true/false
    #
    # @example via job, this is the typical usage and will create a run record in the DB
    #   When definition.refresh_strategy == "concurrent"
    #   MatViews::Jobs::Adapter.enqueue(MatViews::Services::RegularRefresh, definition.id, **options)
    #
    class RegularRefresh < BaseService
      private

      ##
      # Perform the refresh.
      #
      # Steps:
      # - Validate name & existence.
      # - Run `REFRESH MATERIALIZED VIEW`.
      # - Optionally compute row count.
      #
      # @return [MatViews::ServiceResponse]
      #   - `status: :updated` on success, with `response` containing:
      #     - `view` - the qualified view name
      #     - `row_count_before` - if requested and available
      #     - `row_count_after` - if requested and available
      #   - `status: :error` with `error` on failure, with `error` containing:
      #     - serlialized exception class, message, and backtrace in a hash
      #
      def _run
        sql = "REFRESH MATERIALIZED VIEW #{qualified_rel}"

        self.response = { view: "#{schema}.#{rel}", sql: [sql] }

        response[:row_count_before] = fetch_rows_count
        conn.execute(sql)
        response[:row_count_after] = fetch_rows_count

        ok(:updated)
      end

      ##
      # Validation step (invoked by BaseService#run before execution).
      # Ensures view exists.
      #
      # @api private
      #
      # @return [void]
      #
      def prepare
        raise_err "Materialized view #{schema}.#{rel} does not exist" unless view_exists?

        nil
      end

      ##
      # Assign the request parameters.
      # Called by {#run} before {#prepare}.
      #
      # @api private
      # @return [void]
      #
      def assign_request
        self.request = { row_count_strategy: row_count_strategy }
      end
    end
  end
end
