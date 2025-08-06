require 'rails'
ENV['RAILS_ENV'] ||= 'test'
abort("The Rails environment is running in production mode!") if Rails.env.production?

require 'spec_helper'
require File.expand_path("dummy/config/environment", __dir__) if defined?(Rails)
require "rspec/rails"

begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end
RSpec.configure do |config|
  config.fixture_paths = [
    Rails.root.join('spec/fixtures')
  ]
  config.use_transactional_fixtures = true
  config.filter_rails_from_backtrace!
end
