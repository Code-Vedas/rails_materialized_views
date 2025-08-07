# frozen_string_literal: true

require 'rails/generators'
require 'rails/generators/migration'

module MatViews
  module Generators
    # InstallGenerator is responsible for installing MatViews by copying migrations and an initializer.
    # It also provides a method to show a success message after installation.
    class InstallGenerator < Rails::Generators::Base
      include Rails::Generators::Migration

      source_root File.expand_path('templates', __dir__)

      desc 'Installs MatViews: copies migrations and initializer.'

      def copy_migrations
        migration_template 'create_mat_view_definitions.rb', 'db/migrate/create_mat_view_definitions.rb'
        migration_template 'create_mat_view_refresh_runs.rb', 'db/migrate/create_mat_view_refresh_runs.rb'
      end

      def create_initializer
        copy_file 'mat_views_initializer.rb', 'config/initializers/mat_views.rb'
      end

      def show_success_message
        say "\n✅ MatViews installed! Don't forget to run:  rails db:migrate\n", :green
      end

      # Required by Rails to generate timestamps
      def self.next_migration_number(_path)
        if @prev_migration_nr
          @prev_migration_nr += 1
        else
          @prev_migration_nr = Time.now.utc.strftime('%Y%m%d%H%M%S').to_i
        end
        @prev_migration_nr.to_s
      end
    end
  end
end
