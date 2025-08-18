# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

module MatViews
  ##
  # Configuration for the MatViews engine.
  #
  # This class provides customization points for how MatViews integrates
  # with background job systems and controls default behavior across
  # the engine.
  #
  # @example Configure in an initializer
  #   MatViews.configure do |config|
  #     config.job_adapter = :sidekiq
  #     config.job_queue   = :low_priority
  #   end
  #
  # Supported job adapters:
  # - `:active_job` (default)
  # - `:sidekiq`
  # - `:resque`
  #
  class Configuration
    ##
    # The job adapter to use for enqueuing jobs.
    #
    # @return [Symbol] :active_job, :sidekiq, or :resque
    attr_accessor :job_adapter

    ##
    # The default queue name to use for jobs.
    #
    # @return [Symbol, String]
    attr_accessor :job_queue

    ##
    # Initialize with defaults.
    #
    # @return [void]
    def initialize
      @job_adapter = :active_job
      @job_queue   = :default
    end
  end
end
