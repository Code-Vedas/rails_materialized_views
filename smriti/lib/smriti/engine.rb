# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

##
# Smriti is a Rails engine that provides first-class support for
# PostgreSQL materialised views in Rails applications.
module Smriti
  class << self
    attr_accessor :importmap
  end
  ##
  # Rails Engine for Smriti.
  #
  # This engine encapsulates all functionality related to
  # materialised views, including:
  # - Defining materialised view definitions
  # - Creating and refreshing views
  # - Managing background jobs for refresh/create/delete
  #
  # By isolating the namespace, it ensures that routes, models,
  # and helpers do not conflict with the host application.
  #
  # @example Mounting the engine in a Rails application
  #   # config/routes.rb
  #   Rails.application.routes.draw do
  #     mount Smriti::Engine => "/smriti"
  #   end
  #
  class Engine < ::Rails::Engine
    isolate_namespace Smriti

    initializer 'smriti.load_config' do
      Smriti.configuration ||= Smriti::Configuration.new
    end

    initializer 'smriti.javascript' do |app|
      app.config.assets.paths << root.join('app/javascript')
    end

    initializer 'smriti.importmap', before: 'importmap' do |_app|
      next unless defined?(Importmap)

      Smriti.importmap = Importmap::Map.new
      Smriti.importmap.draw(root.join('config/importmap.rb'))
      Smriti.importmap.cache_sweeper(watches: root.join('app/javascript'))

      ActiveSupport.on_load(:action_controller_base) do
        before_action { Smriti.importmap.cache_sweeper.execute_if_updated }
      end
    end

    def self.locale_code_mapping
      @locale_code_mapping ||= begin
        mappings = Dir[root.join('config', 'locales', '*.yml')].map.to_h do |file|
          code = File.basename(file, '.yml').to_sym
          name = I18n.t('i18n.name', locale: code)
          [code, name]
        end
        mappings.sort_by { |code, _name| code.to_s }.to_h
      end
    end

    def self.available_locales
      @available_locales ||= locale_code_mapping.keys.freeze
    end

    def self.default_locale = :en
    def self.loaded_spec = Gem.loaded_specs['smriti']
    def self.project_name = loaded_spec&.name
    def self.project_version = Smriti::VERSION
    def self.project_homepage = loaded_spec&.homepage
    def self.company_name = 'Codevedas Inc.'
    def self.documentation_uri = loaded_spec&.metadata&.[]('documentation_uri')
    def self.bug_tracker_uri = loaded_spec&.metadata&.[]('bug_tracker_uri')
    def self.support_uri = loaded_spec&.metadata&.[]('support_uri')
    def self.rubygems_uri = loaded_spec&.metadata&.[]('rubygems_uri')
  end
end
