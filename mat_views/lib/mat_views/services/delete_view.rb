# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

module MatViews
  module Services
    ##
    # Service that safely drops a PostgreSQL materialized view.
    #
    # Options:
    # - `cascade:` (Boolean, default: false) → drop with CASCADE instead of RESTRICT
    # - `row_count_strategy:` (Symbol, default: :none) → one of `:estimated`, `:exact`, or `:none or nil` to control row count reporting
    #
    # Returns a {MatViews::ServiceResponse}
    #
    # @see MatViews::DeleteViewJob
    # @see MatViews::MatViewRun
    #
    # @example Drop a view if it exists
    #   svc = MatViews::Services::DeleteView.new(defn, **options)
    #   svc.call
    #
    # @example Force drop with CASCADE
    #   MatViews::Services::DeleteView.new(defn, cascade: true).call
    #
    # @example via job, this is the typical usage and will create a run record in the DB
    #   MatViews::Jobs::Adapter.enqueue(MatViews::Services::DeleteViewJob, definition.id, **options)
    #
    class DeleteView < BaseService
      ##
      # Whether to cascade the drop (default: false).
      #
      # @return [Boolean]
      attr_reader :cascade

      ##
      # @param definition [MatViews::MatViewDefinition]
      # @param cascade [Boolean] drop with CASCADE instead of RESTRICT
      # @param row_count_strategy [Symbol, nil] one of `:estimated`, `:exact`, or `nil` (default: `:estimated`)
      def initialize(definition, cascade: false, row_count_strategy: :estimated)
        super(definition, row_count_strategy: row_count_strategy)
        @cascade = cascade ? true : false
      end

      private

      ##
      # Run the drop operation.
      #
      # Steps:
      # - Validate name format
      # - return :skipped if absent
      # - Execute DROP MATERIALIZED VIEW.
      #
      # @api private
      #
      # @return [MatViews::ServiceResponse]
      #   - `status: :deleted or :skipped` on success, with `response` containing:
      #     - `view` - the qualified view name
      #     - `row_count_before` - if requested and available
      #     - `row_count_after` - if requested and available
      #   - `status: :error` with `error` on failure, with `error` containing:
      #     - serlialized exception class, message, and backtrace in a hash
      def _run
        self.response = { view: "#{schema}.#{rel}", sql: [drop_sql] }

        return ok(:skipped) unless view_exists?

        response[:row_count_before] = fetch_rows_count
        conn.execute(drop_sql)
        response[:row_count_after] = UNKNOWN_ROW_COUNT # view is gone
        ok(:deleted)
      end

      ##
      # Assign the request parameters.
      # Called by {#call} before {#prepare}.
      # Sets `concurrent: true` in the request hash.
      #
      # @api private
      # @return [void]
      #
      def assign_request
        self.request = { row_count_strategy: row_count_strategy, cascade: cascade }
      end

      ##
      # Validation step (invoked by BaseService#call before execution).
      # Empty for this service as no other preparation is needed.
      #
      # @api private
      #
      # @return [void]
      def prepare; end

      ##
      # Build the SQL DROP statement.
      #
      # @api private
      # @return [String]
      #
      def drop_sql
        drop_mode = cascade ? ' CASCADE' : ' RESTRICT'
        %(DROP MATERIALIZED VIEW IF EXISTS #{qualified_rel}#{drop_mode})
      end
    end
  end
end
