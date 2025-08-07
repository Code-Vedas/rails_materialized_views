# frozen_string_literal: true

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
