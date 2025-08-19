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
    # - `if_exists:` (Boolean, default: true) → idempotent drop (skip if absent)
    # - `cascade:`   (Boolean, default: false) → use CASCADE instead of RESTRICT
    #
    # Returns a {MatViews::ServiceResponse} from {MatViews::Services::BaseService}:
    # - `ok(:deleted, ...)` when dropped successfully
    # - `ok(:skipped, ...)` when absent and `if_exists: true`
    # - `err("...")` or `error_response(...)` on validation or execution error
    #
    # @see MatViews::DeleteViewJob
    # @see MatViews::MatViewDeleteRun
    #
    # @example Drop a view if it exists
    #   svc = MatViews::Services::DeleteView.new(defn)
    #   svc.run
    #
    # @example Force drop with CASCADE
    #   MatViews::Services::DeleteView.new(defn, cascade: true).run
    #
    class DeleteView < BaseService
      ##
      # Whether to cascade the drop (default: false).
      #
      # @return [Boolean]
      attr_reader :cascade

      ##
      # Whether to allow idempotent skipping if view is absent (default: true).
      #
      # @return [Boolean]
      attr_reader :if_exists

      ##
      # @param definition [MatViews::MatViewDefinition]
      # @param cascade [Boolean] drop with CASCADE instead of RESTRICT
      # @param if_exists [Boolean] skip if view not present
      def initialize(definition, cascade: false, if_exists: true)
        super(definition)
        @cascade   = cascade ? true : false
        @if_exists = if_exists ? true : false
      end

      ##
      # Run the drop operation.
      #
      # Steps:
      # - Validate name format and (optionally) existence.
      # - Return `:skipped` if absent and `if_exists` true.
      # - Execute DROP MATERIALIZED VIEW.
      #
      # @return [MatViews::ServiceResponse]
      #
      def run
        prep = prepare!
        return prep if prep

        res = skip_early_if_absent
        return res if res

        perform_drop
      end

      private

      # ────────────────────────────────────────────────────────────────
      # internal
      # ────────────────────────────────────────────────────────────────

      ##
      # Execute the DROP MATERIALIZED VIEW statement.
      #
      # @api private
      # @return [MatViews::ServiceResponse]
      #
      def perform_drop
        conn.execute(sql)

        ok(:deleted,
           payload: { view: "#{schema}.#{rel}" },
           meta: { sql: sql, cascade: cascade, if_exists: if_exists })
      rescue ActiveRecord::StatementInvalid => e
        msg = "#{e.message} — dependencies exist. Use cascade: true to force drop."
        error_response(
          e.class.new(msg),
          meta: { sql: sql, cascade: cascade, if_exists: if_exists },
          payload: { view: "#{schema}.#{rel}" }
        )
      rescue StandardError => e
        error_response(
          e,
          meta: { sql: sql, cascade: cascade, if_exists: if_exists },
          payload: { view: "#{schema}.#{rel}" }
        )
      end

      ##
      # Skip early if view is absent and `if_exists` is true.
      #
      # @api private
      # @return [MatViews::ServiceResponse, nil]
      #
      def skip_early_if_absent
        return nil unless if_exists
        return nil if view_exists?

        ok(:skipped,
           payload: { view: "#{schema}.#{rel}" },
           meta: { sql: nil, cascade: cascade, if_exists: if_exists })
      end

      ##
      # Build the SQL DROP statement.
      #
      # @api private
      # @return [String]
      #
      def sql
        @sql ||= build_sql
      end

      ##
      # Validate name and existence depending on options.
      #
      # @api private
      # @return [MatViews::ServiceResponse, nil]
      #
      def prepare!
        return err("Invalid view name format: #{definition.name.inspect}") unless valid_name?
        return nil if if_exists # skip hard existence check

        return err("Materialized view #{schema}.#{rel} does not exist") unless view_exists?

        nil
      end

      ##
      # Construct DROP SQL with cascade/restrict options.
      #
      # @api private
      # @return [String]
      #
      def build_sql
        drop_mode = cascade ? ' CASCADE' : ' RESTRICT'
        %(DROP MATERIALIZED VIEW IF EXISTS #{qualified_rel}#{drop_mode})
      end

      ##
      # Ensure the matview name is a simple identifier.
      #
      # @api private
      # @return [Boolean]
      #
      def valid_name?
        /\A[a-zA-Z_][a-zA-Z0-9_]*\z/.match?(definition.name.to_s)
      end
    end
  end
end
