# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

require 'ext/exception'
require 'smriti/version'
require 'smriti/engine'
require 'smriti/helpers/ui_test_ids'
require 'smriti/configuration'
require 'smriti/jobs/adapter'
require 'smriti/service_response'
require 'smriti/services/base_service'
require 'smriti/services/create_view'
require 'smriti/services/regular_refresh'
require 'smriti/services/concurrent_refresh'
require 'smriti/services/swap_refresh'
require 'smriti/services/delete_view'
require 'smriti/services/check_matview_exists'
require 'smriti/admin/auth_bridge'
require 'smriti/admin/default_auth'

##
# Smriti is a Rails engine that provides first-class support for
# PostgreSQL materialised views in Rails applications.
#
# Features include:
# - Declarative definitions for materialised views
# - Safe creation, refresh (regular, concurrent, swap), and deletion
# - Background job integration (ActiveJob, Sidekiq, Resque)
# - Tracking of run history and metrics
# - Rake task helpers for operational workflows
#
# Usage:
#   Smriti.configure do |config|
#     config.job_queue = :low_priority
#     config.job_adapter = :sidekiq
#   end
#
# Once mounted, Rails apps can leverage Smriti services and jobs
# to manage materialised views consistently.
module Smriti
  class << self
    # Global configuration for Smriti
    # @return [Smriti::Configuration]
    attr_reader :configuration

    # Configure Smriti via block.
    #
    # Example:
    #   Smriti.configure do |config|
    #     config.job_adapter = :sidekiq
    #     config.job_queue   = :materialised
    #   end
    def configure
      @configuration ||= Configuration.new
      yield(configuration)

      configuration.admin_ui[:row_count_strategy] ||= :none
    end
  end
end
