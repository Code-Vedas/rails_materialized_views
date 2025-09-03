# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

require 'ext/exception'
require 'mat_views/version'
require 'mat_views/engine'
require 'mat_views/configuration'
require 'mat_views/jobs/adapter'
require 'mat_views/service_response'
require 'mat_views/services/base_service'
require 'mat_views/services/create_view'
require 'mat_views/services/regular_refresh'
require 'mat_views/services/concurrent_refresh'
require 'mat_views/services/swap_refresh'
require 'mat_views/services/delete_view'

##
# MatViews is a Rails engine that provides first-class support for
# PostgreSQL materialized views in Rails applications.
#
# Features include:
# - Declarative definitions for materialized views
# - Safe creation, refresh (regular, concurrent, swap), and deletion
# - Background job integration (ActiveJob, Sidekiq, Resque)
# - Tracking of run history and metrics
# - Rake task helpers for operational workflows
#
# Usage:
#   MatViews.configure do |config|
#     config.job_queue = :low_priority
#     config.job_adapter = :sidekiq
#   end
#
# Once mounted, Rails apps can leverage MatViews services and jobs
# to manage materialized views consistently.
module MatViews
  class << self
    # Global configuration for MatViews
    # @return [MatViews::Configuration]
    attr_reader :configuration

    # Configure MatViews via block.
    #
    # Example:
    #   MatViews.configure do |config|
    #     config.job_adapter = :sidekiq
    #     config.job_queue   = :materialized
    #   end
    def configure
      @configuration ||= Configuration.new
      yield(configuration)
    end
  end
end
