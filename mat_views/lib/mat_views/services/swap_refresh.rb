# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

require 'securerandom'

module MatViews
  module Services
    ##
    # Service that performs a **swap-style refresh** of a materialized view.
    #
    # Instead of locking the existing view, this strategy builds a new
    # temporary materialized view and atomically swaps it in. This approach
    # minimizes downtime and allows for safer rebuilds of large views.
    #
    # Steps:
    # 1. Create a temporary MV from the provided SQL.
    # 2. In a transaction: rename original → old, tmp → original, drop old.
    # 3. Recreate declared unique indexes (if any).
    #
    # Options:
    # - `row_count_strategy:` (Symbol, default: :none) → one of `:estimated`, `:exact`, or `:none or nil` to control row count reporting
    #
    # Returns a {MatViews::ServiceResponse}
    #
    # @see MatViews::Services::ConcurrentRefresh
    # @see MatViews::Services::RegularRefresh
    #
    # @example Direct usage
    #   svc = MatViews::Services::SwapRefresh.new(definition, **options)
    #   response = svc.call
    #   response.success? # => true/false
    #
    # @example via job, this is the typical usage and will create a run record in the DB
    #   When definition.refresh_strategy == "concurrent"
    #   MatViews::Jobs::Adapter.enqueue(MatViews::Services::SwapRefresh, definition.id, **options)
    #
    class SwapRefresh < BaseService
      private

      ##
      # Execute the swap refresh.
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
        self.response = { view: "#{schema}.#{rel}" }

        response[:row_count_before] = fetch_rows_count
        response[:sql] = swap_view
        response[:row_count_after] = fetch_rows_count

        ok(:updated)
      end

      ##
      # Validation step (invoked by BaseService#call before execution).
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
      # Called by {#call} before {#prepare}.
      #
      # @api private
      # @return [void]
      #
      def assign_request
        self.request = { row_count_strategy: row_count_strategy, swap: true }
      end

      ##
      # Perform rename/drop/index recreation in a transaction.
      #
      # @api private
      # @return [Array<String>] SQL steps executed
      def swap_view
        conn.execute(create_temp_view_sql)
        steps = [
          move_current_to_old_sql,
          move_temp_to_current_sql,
          drop_old_view_sql,
          recreate_declared_unique_indexes_sql
        ].compact
        conn.transaction do
          steps.each { |step| conn.execute(step) }
        end

        # prepend the create step
        steps.unshift(create_temp_view_sql)
        steps
      end

      def create_temp_view_sql
        @create_temp_view_sql ||= %(CREATE MATERIALIZED VIEW #{q_tmp} AS #{definition.sql} WITH DATA)
      end

      def move_current_to_old_sql
        %(ALTER MATERIALIZED VIEW #{qualified_rel} RENAME TO #{conn.quote_column_name(old_rel)})
      end

      def move_temp_to_current_sql
        %(ALTER MATERIALIZED VIEW #{q_tmp} RENAME TO #{conn.quote_column_name(rel)})
      end

      def drop_old_view_sql
        %(DROP MATERIALIZED VIEW #{q_old})
      end

      ##
      # Quote the temporary materialized view name.
      #
      # @api private
      # @return [String] quoted temporary view name
      def q_tmp
        @q_tmp ||= conn.quote_table_name("#{schema}.#{tmp_rel}")
      end

      ##
      # Quote the original materialized view name.
      #
      # @api private
      # @return [String] quoted original view name
      def q_old
        @q_old ||= conn.quote_table_name("#{schema}.#{old_rel}")
      end

      ##
      # Fully-qualified, safely-quoted temporary relation name.
      #
      # @api private
      # @return [String]
      def tmp_rel
        @tmp_rel ||= "#{rel}__tmp_#{SecureRandom.hex(4)}"
      end

      ##
      # Fully-qualified, safely-quoted old relation name.
      #
      # @api private
      # @return [String]
      def old_rel
        @old_rel ||= "#{rel}__old_#{SecureRandom.hex(4)}"
      end

      ##
      # Recreate declared unique indexes on the swapped-in view.
      #
      # @api private
      # @return [String] SQL statements to execute
      def recreate_declared_unique_indexes_sql
        cols = Array(definition.unique_index_columns).map(&:to_s).reject(&:empty?)
        return nil if cols.empty?

        quoted_cols = cols.map { |col| conn.quote_column_name(col) }.join(', ')
        idx_name    = conn.quote_column_name("#{rel}_uniq_#{cols.join('_')}")
        q_rel       = conn.quote_table_name("#{schema}.#{rel}")

        %(CREATE UNIQUE INDEX #{idx_name} ON #{q_rel} (#{quoted_cols}))
      end
    end
  end
end
