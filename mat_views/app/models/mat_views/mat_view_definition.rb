# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

##
# Top-level namespace for the mat_views engine.
module MatViews
  ##
  # Represents a **materialised view definition** managed by the engine.
  #
  # A definition stores the canonical name and SQL for a materialised view and
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
    # validates :name that must be present, unique, and a valid identifier.
    validates :name,
              presence: true,
              uniqueness: true,
              format: { with: /\A[a-zA-Z_][a-zA-Z0-9_]*\z/ }

    ##
    # @!attribute sql
    # validates :sql that must be present and begin with SELECT.
    validates :sql,
              presence: true,
              format: { with: /\A\s*SELECT/i, message: :invalid }

    ##
    # @!attribute unique_index_columns
    # validates :unique_index_columns to be non-empty when using `refresh_strategy=concurrent`.
    validates :unique_index_columns,
              length: { minimum: 1, message: :at_least_one },
              if: -> { refresh_strategy == 'concurrent' }

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

    # ────────────────────────────────────────────────────────────────
    # Scopes for ordering, searching, filtering
    # ────────────────────────────────────────────────────────────────

    ##
    # Scope ordered by name
    # Orders by the `name` attribute.
    #
    # @param dir [Symbol, String] `:asc` or `:desc`
    # @return [ActiveRecord::Relation<MatViews::MatViewDefinition>]
    scope :ordered_by_name, ->(dir) { order("name #{dir.to_s.upcase}") }

    ##
    # Scope ordered by refresh_strategy
    # Orders by the `refresh_strategy` attribute, using humanized enum labels.
    #
    # @param dir [Symbol, String] `:asc` or `:desc`
    # @return [ActiveRecord::Relation<MatViews::MatViewDefinition>]
    scope :ordered_by_refresh_strategy, ->(dir) { ordered_by_enum(enum_values: refresh_strategies, enum_name: :refresh_strategy, direction: dir) }

    ## Scope ordered by schedule_cron
    # Orders by the `schedule_cron` attribute, NULLs last.
    #
    # @param dir [Symbol, String] `:asc` or `:desc`
    # @return [ActiveRecord::Relation<MatViews::MatViewDefinition>]
    scope :ordered_by_schedule_cron, ->(dir) { order("schedule_cron #{dir.to_s.upcase} NULLS LAST") }

    ## Scope ordered by last_run_at
    # Orders by the timestamp of the most recent associated run's `started_at`, NULLs last.
    #
    # @param dir [Symbol, String] `:asc` or `:desc`
    # @return [ActiveRecord::Relation<MatViews::MatViewDefinition>]
    scope :ordered_by_last_run_at, lambda { |dir|
      dir = dir.to_s.casecmp('asc').zero? ? 'ASC' : 'DESC'

      order(Arel.sql(<<~SQL.squish))
        (
          SELECT MAX(r.created_at)
          FROM mat_view_runs r
          WHERE r.mat_view_definition_id = mat_view_definitions.id
        ) #{dir} NULLS LAST
      SQL
    }

    ## Scope search by name
    # Searches the `name` attribute using ILIKE.
    #
    # @param term [String] search term
    # @return [ActiveRecord::Relation<MatViews::MatViewDefinition>]
    scope :search_by_name, ->(term) { where('name ILIKE ?', "%#{term}%") }

    ## Scope search by refresh_strategy
    # Searches the `refresh_strategy` attribute using humanized enum labels.
    #
    # @param term [String] search term
    # @return [ActiveRecord::Relation<MatViews::MatViewDefinition>]
    scope :search_by_refresh_strategy, ->(term) { search_by_enum(enum_values: refresh_strategies, enum_name: :refresh_strategy, term: term) }

    ## Scope search by schedule_cron
    # Searches the `schedule_cron` attribute using ILIKE.
    #
    # @param term [String] search term
    # @return [ActiveRecord::Relation<MatViews::MatViewDefinition>]
    scope :search_by_schedule_cron, ->(term) { where('schedule_cron ILIKE ?', "%#{term}%") }

    ## Scope search by last_run_at
    # Searches the timestamp of the most recent associated run's `started_at` using ILIKE
    #
    # @param term [String] search term
    # @return [ActiveRecord::Relation<MatViews::MatViewDefinition>]
    scope :search_by_last_run_at, lambda { |term|
      where(<<~SQL, like: "%#{term}%")
        EXISTS (
          SELECT 1
          FROM (
            SELECT MAX(r.started_at) AS last_run_at
            FROM mat_view_runs r
            WHERE r.mat_view_definition_id = mat_view_definitions.id
          ) m
          WHERE CAST(m.last_run_at AS TEXT) ILIKE :like
        )
      SQL
    }

    ## Scope filtered by name
    # Filters by exact match on the `name` attribute.
    #
    # @param name [String] filter value
    # @return [ActiveRecord::Relation<MatViews::MatViewDefinition>]
    scope :filtered_by_name, ->(name) { where(name:) }

    ## Scope filtered by refresh_strategy
    # Filters by exact match on the `refresh_strategy` attribute.
    #
    # @param refresh_strategy [String] filter value, one of `"regular"`, `"concurrent"`, `"swap"`
    # @return [ActiveRecord::Relation<MatViews::MatViewDefinition>]
    scope :filtered_by_refresh_strategy, ->(refresh_strategy) { where(refresh_strategy:) }

    ## Scope filtered by schedule_cron
    # Filters by exact match on the `schedule_cron` attribute, or NULL/empty.
    #
    # @param schedule_cron [String] filter value, or `"no_value"` to match NULL/empty
    # @return [ActiveRecord::Relation<MatViews::MatViewDefinition>]
    scope :filtered_by_schedule_cron, lambda { |schedule_cron|
      if schedule_cron == 'no_value'
        where(schedule_cron: nil).or(where(schedule_cron: ''))
      else
        where('schedule_cron ILIKE ?', "%#{schedule_cron.tr('_', ' ')}%")
      end
    }

    # ────────────────────────────────────────────────────────────────
    # Class methods
    # ────────────────────────────────────────────────────────────────

    class << self
      ##
      # Returns options for filters in admin UI datatable.
      #
      # @return [Array<Array(String, String)>] array of `[label, value]` pairs
      def filter_options_for_name
        order(:name).distinct.pluck(:name).map { |name| [name, name] }
      end

      ##
      # Returns options for filters in admin UI datatable.
      #
      # @return [Array<Array(String, String)>] array of `[label, value]` pairs
      def filter_options_for_refresh_strategy
        order(:refresh_strategy).distinct.pluck(:refresh_strategy).compact.map { |rs| [human_enum_name(:refresh_strategy, rs), rs] }
      end

      ##
      # Returns options for filters in admin UI datatable.
      #
      # @return [Array<Array(String, String)>] array of `[label, value]` pairs
      def filter_options_for_schedule_cron
        order(:schedule_cron).distinct.pluck(:schedule_cron).compact.map { |sc| [sc, sc.tr(' ', '_')] }
      end
    end

    # ────────────────────────────────────────────────────────────────
    # Instance methods
    # ────────────────────────────────────────────────────────────────

    ##
    # Returns the most recent run associated with this definition.
    #
    # @return [MatViews::MatViewRun, nil] the latest run or `nil` if none exist
    #

    def last_run
      mat_view_runs.order(created_at: :desc).first
    end
  end
end
