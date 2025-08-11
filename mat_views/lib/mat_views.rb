# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

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

# MatViews is a Rails engine that provides support for materialized views.
#
# It includes functionality for defining, refreshing, and managing materialized views
# within a Rails application. This engine can be mounted in a Rails application to
# leverage its features.
module MatViews
  class << self
    attr_accessor :configuration

    def configure
      self.configuration ||= Configuration.new
      yield(configuration)
    end
  end
end
