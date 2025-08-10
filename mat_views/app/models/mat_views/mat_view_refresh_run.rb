# frozen_string_literal: true

module MatViews
  # MatViewRefreshRun is an ActiveRecord model that tracks the status of materialized view refresh operations.
  class MatViewRefreshRun < ApplicationRecord
    self.table_name = 'mat_view_refresh_runs'

    belongs_to :mat_view_definition, class_name: 'MatViews::MatViewDefinition'

    enum :status, {
      pending: 0, # The refresh operation is queued but not yet started.
      running: 1, # The refresh operation is currently in progress.
      success: 2, # The refresh operation completed successfully.
      failed: 3   # The refresh operation encountered an error.
    }, prefix: :status

    validates :status, presence: true
  end
end
