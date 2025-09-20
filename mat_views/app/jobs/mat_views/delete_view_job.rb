# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

##
# Top-level namespace for the mat_views engine.
module MatViews
  ##
  # ActiveJob that handles *deletion* of PostgreSQL materialized views via
  # {MatViews::Services::DeleteView}.
  #
  # This job mirrors {MatViews::CreateViewJob} and {MatViews::RefreshViewJob}:
  # it times the run and persists lifecycle state in {MatViews::MatViewRun}.
  #
  # @see MatViews::Services::DeleteView
  # @see MatViews::MatViewDefinition
  # @see MatViews::MatViewRun
  #
  # @example Enqueue a delete job
  #   MatViews::DeleteViewJob.perform_later(definition.id, cascade: true)
  #
  # @example Inline run (test/dev)
  #   MatViews::DeleteViewJob.new.perform(definition.id, false)
  #
  class DeleteViewJob < ApplicationJob
    ###
    # cascade flag for the service call
    # @return [Boolean]
    attr_reader :cascade

    ##
    # Queue name for the job.
    #
    # Uses `MatViews.configuration.job_queue` when configured, otherwise `:default`.
    #
    queue_as { MatViews.configuration.job_queue || :default }

    ##
    # Perform the job for the given materialized view definition.
    #
    # @api public
    #
    # @param mat_view_definition_id [Integer, String] ID of {MatViews::MatViewDefinition}.
    # @param cascade_arg [Boolean, String, Integer, Hash, nil] Cascade option.
    # @param row_count_strategy_arg [:Symbol, String] One of: `:estimated`, `:exact`, `:none` or `nil`.
    #
    # @return [Hash] Serialized {MatViews::ServiceResponse#to_h}:
    #   - `:status` [Symbol]
    #   - `:error` [String, nil]
    #   - `:duration_ms` [Integer]
    #   - `:meta` [Hash]
    #
    # @raise [StandardError] Re-raised on unexpected failure after marking the run failed.
    #
    def perform(mat_view_definition_id, cascade_arg = nil, row_count_strategy_arg = nil)
      definition = MatViews::MatViewDefinition.find(mat_view_definition_id)
      record_run(definition, :drop) do
        MatViews::Services::DeleteView.new(definition,
                                           cascade: cascade?(cascade_arg),
                                           row_count_strategy: normalize_strategy(row_count_strategy_arg)).call
      end
    end

    private

    ##
    # Evaluate if a value is "truthy" for cascade.
    #
    # @api private
    # @param value [TrueClass, FalseClass, String, Integer, nil, Object]
    # @return [Boolean]
    #
    def cascade?(value)
      case value
      when true
        true
      when String
        %w[true 1 yes].include?(value.strip.downcase)
      when Integer
        value == 1
      else
        false
      end
    end
  end
end
