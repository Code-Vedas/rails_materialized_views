# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

require 'rails/generators'
require 'rails/generators/migration'
require 'rails/generators/active_record'

##
# Top-level namespace for the mat_views engine.
module MatViews
  ##
  # Namespace for Rails generators shipped with the mat_views engine.
  module Generators
    ##
    # Rails generator that installs MatViews into a host application by:
    #
    # 1. Copying migrations for definitions and run-tracking tables.
    # 2. Creating an initializer at `config/initializers/mat_views.rb`.
    # 3. Printing a success message with next steps.
    #
    # @example Run the installer
    #   bin/rails g mat_views:install
    #
    # @see MatViews::MatViewDefinition
    # @see MatViews::MatViewRefreshRun
    # @see MatViews::MatViewCreateRun
    # @see MatViews::MatViewDeleteRun
    #
    class InstallGenerator < Rails::Generators::Base
      include Rails::Generators::Migration

      ##
      # Directory containing template files for the generator.
      #
      # @return [String] absolute path to templates dir
      #
      source_root File.expand_path('templates', __dir__)

      ##
      # Short description shown in `rails g --help`.
      desc 'Installs MatViews: copies migrations and initializer.'

      ##
      # Copies all required migrations into the host app.
      #
      # @return [void]
      #
      def copy_migrations
        migration_template 'create_mat_view_definitions.rb',  'db/migrate/create_mat_view_definitions.rb'
        migration_template 'create_mat_view_refresh_runs.rb', 'db/migrate/create_mat_view_refresh_runs.rb'
        migration_template 'create_mat_view_create_runs.rb',  'db/migrate/create_mat_view_create_runs.rb'
        migration_template 'create_mat_view_delete_runs.rb',  'db/migrate/create_mat_view_delete_runs.rb'
      end

      ##
      # Creates the engine initializer in the host app.
      #
      # @return [void]
      #
      def create_initializer
        copy_file 'mat_views_initializer.rb', 'config/initializers/mat_views.rb'
      end

      ##
      # Prints a success message after installation.
      #
      # @return [void]
      #
      def show_success_message
        say "\n✅ MatViews installed! Don't forget to run:  rails db:migrate\n", :green
      end

      ##
      # Computes the next migration number for copied migrations.
      #
      # Required by Rails to generate timestamped migration filenames.
      #
      # @param path [String] destination path for migrations
      # @return [String] the next migration number (timestamp)
      #
      def self.next_migration_number(path)
        ActiveRecord::Generators::Base.next_migration_number(path)
      end
    end
  end
end
