# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

module MatViews
  # MatViews is a Rails engine that provides support for materialized views.
  #
  # It includes functionality for defining, refreshing, and managing materialized views
  # within a Rails application. This engine can be mounted in a Rails application to
  # leverage its features.
  class Engine < ::Rails::Engine
    isolate_namespace MatViews

    initializer 'mat_views.load_config' do
      MatViews.configuration ||= MatViews::Configuration.new
    end
  end
end
