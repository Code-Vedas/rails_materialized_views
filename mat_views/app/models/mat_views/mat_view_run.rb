# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

##
# Top-level namespace for the mat_views engine.
module MatViews
  ##
  # ActiveRecord model that tracks the lifecycle of *runs* for
  # materialised views.
  #
  # Each record corresponds to a single attempt to mutate a materialised view
  # from a {MatViews::MatViewDefinition}, storing its status, timing, and
  # any associated error or metadata.
  #
  # This model provides an auditable history of view provisioning across
  # environments, useful for telemetry, dashboards, and debugging.
  #
  # @see MatViews::MatViewDefinition
  # @see MatViews::CreateViewJob
  #
  # @example Query recent successful runs
  #   MatViews::MatViewRun.status_success.order(created_at: :desc).limit(10)
  #
  # @example Check if a definition has any failed runs
  #   definition.mat_view_runs.status_failed.any?
  #
  class MatViewRun < ApplicationRecord
    ##
    # Underlying database table name.
    self.table_name = 'mat_view_runs'

    ##
    # The definition this run belongs to.
    #
    # @return [MatViews::MatViewDefinition]
    #
    belongs_to :mat_view_definition, class_name: 'MatViews::MatViewDefinition'

    ##
    # Status of the create run.
    #
    # @!attribute [r] status
    #   @return [Symbol] One of:
    #     - `:running` - currently executing
    #     - `:success` - completed successfully
    #     - `:failed` - encountered an error
    #
    enum :status, {
      running: 0,
      success: 1,
      failed: 2
    }, prefix: :status

    # Operation type of the run.
    #
    # @!attribute [r] operation
    #   @return [Symbol] One of:
    #     - `:create` - initial creation of the materialised view
    #     - `:refresh` - refreshing an existing view
    #     - `:drop` - dropping the materialised view
    enum :operation, {
      create: 0,
      refresh: 1,
      drop: 2
    }, prefix: :operation

    ##
    # Validations
    #
    # Ensures that a status is always present.
    validates :status, presence: true

    # ───────────────────────────────────────────────────────────────
    # Scopes for runs, ordering, searching, filtering
    # ───────────────────────────────────────────────────────────────

    ##
    # Scope create runs
    # All runs with `operation: :create`.
    # @return [ActiveRecord::Relation<MatViews::MatViewRun>]
    scope :create_runs, -> { where(operation: :create) }

    ##
    # Scope refresh runs
    # All runs with `operation: :refresh`.
    # @return [ActiveRecord::Relation<MatViews::MatViewRun>]
    scope :refresh_runs, -> { where(operation: :refresh) }

    ##
    # Scope drop runs
    # All runs with `operation: :drop`.
    # @return [ActiveRecord::Relation<MatViews::MatViewRun>]
    scope :drop_runs,    -> { where(operation: :drop) }

    ##
    # Scope ordered by operation
    # Orders by the `operation` attribute using humanized enum labels.
    #
    # @param dir [Symbol, String] `:asc` or `:desc`
    # @return [ActiveRecord::Relation<MatViews::MatViewRun>]
    scope :ordered_by_operation, ->(dir) { ordered_by_enum(enum_values: operations, enum_name: :operation, direction: dir) }

    ##
    # Scope ordered by definition name
    # Orders by the associated definition's `name` attribute.
    #
    # @param dir [Symbol, String] `:asc` or `:desc`
    # @return [ActiveRecord::Relation<MatViews::MatViewRun>]
    scope :ordered_by_definition, ->(dir) { left_joins(:mat_view_definition).order("mat_view_definitions.name #{dir.to_s.upcase}") }

    ##
    # Scope ordered by started_at
    # Orders by the `started_at` attribute.
    #
    # @param dir [Symbol, String] `:asc` or `:desc`
    # @return [ActiveRecord::Relation<MatViews::MatViewRun>]
    scope :ordered_by_started_at, ->(dir) { order("started_at #{dir.to_s.upcase}") }

    ##
    # Scope ordered by the 'status' attribute using humanized enum labels.
    #
    # @param dir [Symbol, String] `:asc` or `:desc`
    # @return [ActiveRecord::Relation<MatViews::MatViewRun>]
    scope :ordered_by_status, ->(dir) { ordered_by_enum(enum_values: statuses, enum_name: :status, direction: dir) }

    ##
    # Scope ordered by duration_ms
    # Orders by the `duration_ms` attribute.
    #
    # @param dir [Symbol, String] `:asc` or `:desc`
    # @return [ActiveRecord::Relation<MatViews::MatViewRun>]
    scope :ordered_by_duration_ms, ->(dir) { order("duration_ms #{dir.to_s.upcase}") }

    ##
    # Scope search by operation
    # Searches the `operation` attribute using humanized enum labels.
    #
    # @param term [String] search term
    # @return [ActiveRecord::Relation<MatViews::MatViewRun>]
    scope :search_by_operation, ->(term) { search_by_enum(enum_values: operations, enum_name: :operation, term: term) }

    ##
    # Scope search by definition name
    # Searches by the associated definition's `name` attribute using ILIKE.
    #
    # @param term [String] search term
    # @return [ActiveRecord::Relation<MatViews::MatViewRun>]
    scope :search_by_definition, lambda { |term|
      where(<<~SQL, like: "%#{term}%")
        EXISTS (
          SELECT 1
          FROM mat_view_definitions d
          WHERE d.id = mat_view_runs.mat_view_definition_id
            AND d.name ILIKE :like
        )
      SQL
    }

    ##
    # Scope search by status
    # Searches the `status` attribute using humanized enum labels.
    #
    # @param term [String] search term
    # @return [ActiveRecord::Relation<MatViews::MatViewRun>]
    scope :search_by_status, ->(term) { search_by_enum(enum_values: statuses, enum_name: :status, term: term) }

    # Scope search by duration_ms
    # Searches the `duration_ms` attribute by casting to text and using ILIKE.
    # Also supports searching with localized "X milliseconds" format.
    #
    # @param term [String] search term
    # @return [ActiveRecord::Relation<MatViews::MatViewRun>]
    scope :search_by_duration_ms, lambda { |term|
      term_with_ms = I18n.t('mat_views.x_miliseconds', count: term)
      where('CAST(duration_ms AS TEXT) ILIKE ?', "%#{term}%")
        .or(where('CAST(duration_ms AS TEXT) ILIKE ?', "%#{term_with_ms}%"))
    }

    ##
    # Scope filter by operation
    # Filters by the `operation` attribute.
    #
    # @param operation [String, Symbol] operation value
    # @return [ActiveRecord::Relation<MatViews::MatViewRun>]
    scope :filtered_by_operation, ->(operation) { where(operation:) }

    ##
    # Scope filter by definition
    # Filters by the associated definition's ID.
    #
    # @param definition_id [Integer] definition ID
    # @return [ActiveRecord::Relation<MatViews::MatViewRun>]
    scope :filtered_by_definition, lambda { |definition_id|
      where(mat_view_definition_id: definition_id)
    }

    ##
    # Scope filter by status
    # Filters by the `status` attribute.
    #
    # @param status [String, Symbol] status value
    # @return [ActiveRecord::Relation<MatViews::MatViewRun>]
    scope :filtered_by_status, ->(status) { where(status:) }

    # ──────────────────────────────────────────────────────────────
    # Class methods
    # ──────────────────────────────────────────────────────────────

    class << self
      # Options for filtering by operation
      #
      # @return [Array<Array(String, String)>] array of `[label, value]` pairs
      def filter_options_for_operation
        order(:operation).distinct.pluck(:operation).compact.map { |operation| [human_enum_name(:operation, operation), operation] }
      end

      # Options for filtering by definition
      #
      # @return [Array<Array(String, Integer)>] array of `[name, id]` pairs
      def filter_options_for_definition
        MatViews::MatViewDefinition.order(:name).pluck(:name, :id)
      end

      # Options for filtering by status
      #
      # @return [Array<Array(String, String)>] array of `[label, value]` pairs
      def filter_options_for_status
        order(:status).distinct.pluck(:status).compact.map { |status| [human_enum_name(:status, status), status] }
      end
    end

    # ──────────────────────────────────────────────────────────────
    # Instance methods
    # ──────────────────────────────────────────────────────────────

    ##
    # Metadata associated with the run.
    #
    # This is a JSONB column storing arbitrary structured data about the run,
    # such as database responses, row counts, etc.
    #
    # @return [Hash] Parsed JSON metadata.
    def meta
      self[:meta] || {}
    end

    ##
    # Error message if the run failed.
    #
    # Extracted from `meta['error']['message']` if present.
    #
    # @return [String, nil] Error message or `nil` if none.
    def error_message
      meta.dig('error', 'message')
    end

    ##

    # row count before the operation, if applicable
    # @return [Integer, nil]
    def row_count_before
      meta.dig('response', 'row_count_before')
    end

    # row count after the operation, if applicable
    # @return [Integer, nil]
    def row_count_after
      meta.dig('response', 'row_count_after')
    end
  end
end
