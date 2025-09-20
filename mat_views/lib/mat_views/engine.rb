# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

##
# MatViews is a Rails engine that provides first-class support for
# PostgreSQL materialized views in Rails applications.
module MatViews
  class << self
    attr_accessor :importmap
  end
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

    initializer 'mat_views.javascript' do |app|
      app.config.assets.paths << root.join('app/javascript')
    end

    initializer 'mat_views.importmap', before: 'importmap' do |_app|
      next unless defined?(Importmap)

      MatViews.importmap = Importmap::Map.new
      MatViews.importmap.draw(root.join('config/importmap.rb'))
      MatViews.importmap.cache_sweeper(watches: root.join('app/javascript'))

      ActiveSupport.on_load(:action_controller_base) do
        before_action { MatViews.importmap.cache_sweeper.execute_if_updated }
      end
    end

    def self.available_locales = %i[en-US en-CA en-AU-ocker en-US-pirate en-AU en-BORK]
    def self.default_locale = :'en-US'
    def self.loaded_spec = Gem.loaded_specs['mat_views']
    def self.project_name = loaded_spec&.name
    def self.project_version = MatViews::VERSION
    def self.project_homepage = loaded_spec&.homepage
    def self.company_name = 'Codevedas Inc.'
    def self.documentation_uri = loaded_spec&.metadata&.[]('documentation_uri')
    def self.bug_tracker_uri = loaded_spec&.metadata&.[]('bug_tracker_uri')
    def self.support_uri = loaded_spec&.metadata&.[]('support_uri')
    def self.rubygems_uri = loaded_spec&.metadata&.[]('rubygems_uri')
  end
end
