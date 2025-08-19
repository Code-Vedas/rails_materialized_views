# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

module MatViews
  ##
  # Rails Engine for MatViews.
  #
  # This engine encapsulates all functionality related to
  # materialized views, including:
  # - Defining materialized view definitions
  # - Creating and refreshing views
  # - Managing background jobs for refresh/create/delete
  #
  # By isolating the namespace, it ensures that routes, models,
  # and helpers do not conflict with the host application.
  #
  # @example Mounting the engine in a Rails application
  #   # config/routes.rb
  #   Rails.application.routes.draw do
  #     mount MatViews::Engine => "/mat_views"
  #   end
  #
  class Engine < ::Rails::Engine
    isolate_namespace MatViews

    initializer 'mat_views.load_config' do
      MatViews.configuration ||= MatViews::Configuration.new
    end
  end
end
