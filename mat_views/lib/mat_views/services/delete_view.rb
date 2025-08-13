# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

module MatViews
  module Services
    # DeleteView safely drops a materialized view.
    # Options:
    #   - if_exists: default true (idempotent)
    #   - cascade:   default false (RESTRICT)
    #
    # Returns MatViews::Response from BaseService:
    #   ok(:deleted, payload: { view: "schema.rel" }, meta: { sql:, cascade:, if_exists: })
    #   ok(:skipped, ...) when not present and if_exists == true
    #   err("...") on failure
    class DeleteView < BaseService
      attr_reader :cascade, :if_exists

      # cascade: Boolean; if_exists: Boolean
      def initialize(definition, cascade: false, if_exists: true)
        super(definition)
        @cascade   = cascade ? true : false
        @if_exists = if_exists ? true : false
      end

      def run
        prep = prepare!
        return prep if prep

        res = skip_early_if_absent
        return res if res

        perform_drop
      end

      # ────────────────────────────────────────────────────────────────
      # internal
      # ────────────────────────────────────────────────────────────────

      def perform_drop
        conn.execute(sql)

        ok(:deleted,
           payload: { view: "#{schema}.#{rel}" },
           meta: { sql: sql, cascade: cascade, if_exists: if_exists })
      rescue ActiveRecord::StatementInvalid => e
        msg = "#{e.message} — dependencies exist. Use cascade: true to force drop."
        error_response(e.class.new(msg), meta: { sql: sql, cascade: cascade, if_exists: if_exists },
                                         payload: { view: "#{schema}.#{rel}" })
      rescue StandardError => e
        error_response(e, meta: {
                         sql: sql,
                         cascade: cascade,
                         if_exists: if_exists
                       }, payload: { view: "#{schema}.#{rel}" })
      end

      def skip_early_if_absent
        # If we want idempotency and the view doesn't exist, skip early.
        return nil unless if_exists
        return nil if view_exists?

        ok(:skipped,
           payload: { view: "#{schema}.#{rel}" },
           meta: { sql: nil, cascade: cascade, if_exists: if_exists })
      end

      def sql
        @sql ||= build_sql
      end

      def prepare!
        return err("Invalid view name format: #{definition.name.inspect}") unless valid_name?
        return nil if if_exists # no hard existence check up-front

        return err("Materialized view #{schema}.#{rel} does not exist") unless view_exists?

        nil
      end

      def build_sql
        drop_mode = cascade ? ' CASCADE' : ' RESTRICT'
        %(DROP MATERIALIZED VIEW IF EXISTS #{qualified_rel}#{drop_mode})
      end

      # Align with other services: only allow a simple identifier for name token.
      def valid_name?
        /\A[a-zA-Z_][a-zA-Z0-9_]*\z/.match?(definition.name.to_s)
      end
    end
  end
end
