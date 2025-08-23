# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

##
# Top-level namespace for the mat_views engine.
module MatViews
  ##
  # Represents a **materialized view definition** managed by the engine.
  #
  # A definition stores the canonical name and SQL for a materialized view and
  # drives lifecycle operations (create, refresh, delete) via background jobs
  # and services. It also tracks operational history through associated
  # run models.
  #
  # Validations ensure a sane PostgreSQL identifier for `name` and that `sql`
  # begins with `SELECT` (case-insensitive).
  #
  # @see MatViews::CreateViewJob
  # @see MatViews::RefreshViewJob
  # @see MatViews::DeleteViewJob
  # @see MatViews::Services::CreateView
  # @see MatViews::Services::RegularRefresh
  # @see MatViews::Services::ConcurrentRefresh
  # @see MatViews::Services::SwapRefresh
  #
  # @example Creating a definition
  #   defn = MatViews::MatViewDefinition.create!(
  #     name: "mv_user_accounts",
  #     sql:  "SELECT users.id, accounts.id AS account_id FROM users JOIN accounts ON ..."
  #   )
  #
  # @example Enqueue a refresh
  #   MatViews::RefreshViewJob.perform_later(defn.id, :estimated)
  #
  class MatViewDefinition < ApplicationRecord
    ##
    # Underlying database table name.
    self.table_name = 'mat_view_definitions'

    # ────────────────────────────────────────────────────────────────
    # Associations
    # ────────────────────────────────────────────────────────────────

    ##
    # Historical create runs linked to this definition.
    #
    # @return [ActiveRecord::Relation<MatViews::MatViewRun>]
    #
    has_many :mat_view_runs,
             dependent: :destroy,
             class_name: 'MatViews::MatViewRun'

    # ────────────────────────────────────────────────────────────────
    # Validations
    # ────────────────────────────────────────────────────────────────

    ##
    # @!attribute name
    #   @return [String] PostgreSQL identifier for the materialized view.
    #
    validates :name,
              presence: true,
              uniqueness: true,
              format: { with: /\A[a-zA-Z_][a-zA-Z0-9_]*\z/ }

    ##
    # @!attribute sql
    #   @return [String] SELECT statement used to materialize the view.
    #
    validates :sql,
              presence: true,
              format: { with: /\A\s*SELECT/i, message: 'must begin with a SELECT' }

    # ────────────────────────────────────────────────────────────────
    # Enums / configuration
    # ────────────────────────────────────────────────────────────────

    ##
    # Refresh strategy that governs which service is used by {RefreshViewJob}.
    #
    # - `:regular`    → {MatViews::Services::RegularRefresh}
    # - `:concurrent` → {MatViews::Services::ConcurrentRefresh}
    # - `:swap`       → {MatViews::Services::SwapRefresh}
    #
    # @!attribute [rw] refresh_strategy
    #   @return [String] one of `"regular"`, `"concurrent"`, `"swap"`
    #
    enum :refresh_strategy, { regular: 0, concurrent: 1, swap: 2 }

    def last_run
      mat_view_runs.order(created_at: :desc).first
    end
  end
end
