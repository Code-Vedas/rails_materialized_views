# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

unless ENV['NO_COVERAGE'] == '1'
  require 'simplecov'

  SimpleCov.start do
    track_files '{app,lib,spec}/**/*.rb'
    add_filter '/spec/'
    add_filter '/config/'
    add_filter '/generators/'
    add_filter 'application_controller.rb'
    add_filter 'application_helper.rb'
    add_filter 'application_job.rb'
    add_filter 'application_mailer.rb'
    add_filter %r{^/lib/.*/version\.rb$}

    enable_coverage :branch
    minimum_coverage 100
  end
end

require 'rails'
ENV['RAILS_ENV'] ||= 'test'
abort('The Rails environment is running in production mode!') if Rails.env.production?
require File.expand_path('dummy/config/environment', __dir__) if File.exist?(File.expand_path(
                                                                               'dummy/config/environment.rb', __dir__
                                                                             ))
require 'mat_views'
require 'rspec/rails'
Dir[File.expand_path('support/**/*.rb', __dir__)].each { |f| require f }

begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end
RSpec.configure do |config|
  config.include ActiveJob::TestHelper
  config.include FactoryBot::Syntax::Methods

  config.use_transactional_fixtures = ENV['E2E'] == '1'
  config.fixture_paths = [Rails.root.join('spec/fixtures')]
  config.filter_rails_from_backtrace!

  config.before(:each, :active_job) do
    ActiveJob::Base.queue_adapter = :test
    clear_enqueued_jobs
    clear_performed_jobs
  end

  config.before(:each, :js) do
    ActiveJob::Base.queue_adapter = :inline
    clear_enqueued_jobs
    clear_performed_jobs
  end

  config.before(:suite) do
    ENV['TZ'] = Time.zone.tzinfo.name
    FactoryBot.definition_file_paths = [File.expand_path('factories', __dir__)]
    FactoryBot.find_definitions

    Rails.application.load_tasks
    FileUtils.rm_rf(Dir[Rails.root.join('tmp/screenshots')])
    FileUtils.rm_rf(Dir[Rails.root.join('tmp/app-screenshots')])
  end

  config.after(:suite) do
    FileUtils.rm_rf(Dir[Rails.root.join('tmp/capybara*')])
    MatViews::MatViewDefinition.destroy_all
    ActiveRecord::Base.connection.execute('ALTER SEQUENCE mat_view_definitions_id_seq RESTART WITH 1')
    ActiveRecord::Base.connection.execute('ALTER SEQUENCE mat_view_runs_id_seq RESTART WITH 1')
  end

  config.after do
    # Reset to default configuration after each example
    MatViews.instance_variable_set(:@configuration, nil)
    MatViews.configure { |c| } # triggers lazy re-init with defaults
  end
end

Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end
