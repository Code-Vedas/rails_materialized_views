# frozen_string_literal: true

require 'rails'
ENV['RAILS_ENV'] ||= 'test'
abort('The Rails environment is running in production mode!') if Rails.env.production?

require 'spec_helper'
require File.expand_path('dummy/config/environment', __dir__) if File.exist?(File.expand_path(
                                                                               'dummy/config/environment.rb', __dir__
                                                                             ))
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

  # Use AJ test adapter for specs that hit ActiveJob
  config.before(:each, :active_job) do
    ActiveJob::Base.queue_adapter = :test
    clear_enqueued_jobs
    clear_performed_jobs
  end

  config.fixture_paths = [
    Rails.root.join('spec/fixtures')
  ]
  config.use_transactional_fixtures = false
  config.filter_rails_from_backtrace!

  config.before(:suite) do
    FactoryBot.definition_file_paths = [File.expand_path('factories', __dir__)]
    FactoryBot.find_definitions
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
