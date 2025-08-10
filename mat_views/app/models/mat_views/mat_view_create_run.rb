# frozen_string_literal: true

module MatViews
  # MatViewCreateRun is an ActiveRecord model that tracks the creation runs of materialized views.
  class MatViewCreateRun < ApplicationRecord
    self.table_name = 'mat_view_create_runs'

    belongs_to :mat_view_definition, class_name: 'MatViews::MatViewDefinition'

    enum :status, {
      pending: 0, # The refresh operation is queued but not yet started.
      running: 1, # The refresh operation is currently in progress.
      success: 2, # The refresh operation completed successfully.
      failed: 3   # The refresh operation encountered an error.
    }

    validates :status, presence: true
  end
end
