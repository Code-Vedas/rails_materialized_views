# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

##
# Top-level namespace for the mat_views engine.
module MatViews
  ##
  # ActiveJob that handles *creation* of PostgreSQL materialized views for a
  # given {MatViews::MatViewDefinition}.
  #
  # The job:
  # 1. Normalizes the `force` argument.
  # 2. Looks up the target {MatViews::MatViewDefinition}.
  # 3. Starts a {MatViews::MatViewRun} row to track lifecycle/timing, with `operation: :create`.
  # 4. Executes {MatViews::Services::CreateView}.
  # 5. Finalizes the run with success/failure, duration, and meta.
  #
  # @see MatViews::Services::CreateView
  # @see MatViews::MatViewDefinition
  # @see MatViews::MatViewRun
  #
  # @example Enqueue a create job
  #   MatViews::CreateViewJob.perform_later(definition.id, force: true)
  #
  # @example Inline run (test/dev)
  #   MatViews::CreateViewJob.new.perform(definition.id, false)
  #
  class CreateViewJob < ApplicationJob
    ##
    # Queue name for the job.
    #
    # Uses `MatViews.configuration.job_queue` when configured, otherwise `:default`.
    #
    # @return [void]
    #
    queue_as { MatViews.configuration.job_queue || :default }

    ##
    # Perform the create job for the given materialized view definition.
    #
    # @api public
    #
    # @param mat_view_definition_id [Integer, String] ID of {MatViews::MatViewDefinition}.
    # @param force_arg [Boolean, Hash, nil] Optional flag or hash (`{ force: true }`)
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
    def perform(mat_view_definition_id, force_arg = nil, row_count_strategy_arg = nil)
      definition = MatViews::MatViewDefinition.find(mat_view_definition_id)

      record_run(definition, :create) do
        MatViews::Services::CreateView.new(definition,
                                           force: force?(force_arg),
                                           row_count_strategy: normalize_strategy(row_count_strategy_arg)).call
      end
    end

    private

    ##
    # Normalize the `force` argument into a boolean.
    #
    # Accepts either a boolean-ish value or a Hash (e.g., `{ force: true }` or `{ "force" => true }`).
    #
    # @api private
    #
    # @param arg [Object] Raw argument; commonly `true/false`, `nil`
    # @return [Boolean] Coerced force flag.
    #
    def force?(arg)
      return false if arg.nil?

      !!arg
    end
  end
end
