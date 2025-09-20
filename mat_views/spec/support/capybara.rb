# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

require 'capybara/rails'
require 'capybara/rspec'
require 'selenium/webdriver'

Capybara.server = :puma, { Silent: true }
Capybara.default_max_wait_time = ENV.fetch('CAPYBARA_WAIT_TIME', 6).to_i
Capybara.match = :smart
Capybara.ignore_hidden_elements = true

Capybara.register_driver :firefox_headless do |app|
  opts = Selenium::WebDriver::Firefox::Options.new
  opts.args << '-headless'
  opts.add_preference('layout.css.devPixelsPerPx', '1.0')
  driver = Capybara::Selenium::Driver.new(app, browser: :firefox, options: opts)
  driver.browser.manage.window.resize_to(1920, 1080)
  driver
end

Capybara.register_driver :remote_firefox do |app|
  url = ENV.fetch('SELENIUM_REMOTE_URL', 'http://localhost:4444/wd/hub')
  opts = Selenium::WebDriver::Firefox::Options.new
  opts.args << '-headless'
  opts.add_preference('layout.css.devPixelsPerPx', '1.0')
  driver = Capybara::Selenium::Driver.new(
    app,
    browser: :remote,
    url: url,
    options: opts
  )
  driver.browser.manage.window.resize_to(1920, 1080)
  driver
end

if ENV['SELENIUM_REMOTE_URL'].present?
  Capybara.default_driver = :remote_firefox
  Capybara.javascript_driver = :remote_firefox
  Capybara.server_host = '0.0.0.0'
  Capybara.server_port = ENV.fetch('CAPYBARA_PORT', '3000').to_i
  Capybara.app_host    = "http://#{ENV.fetch('CAPYBARA_APP_HOST', 'host.docker.internal')}:#{Capybara.server_port}"
  Capybara.always_include_port = true
else
  Capybara.default_driver = :firefox_headless
  Capybara.javascript_driver = :firefox_headless
end

Capybara.disable_animation = true

RSpec.configure do |config|
  config.after(:each, type: :feature) do |example|
    next unless example.exception

    dir = Rails.root.join('tmp/screenshots')
    FileUtils.mkdir_p(dir)
    stamp = Time.now.strftime('%Y%m%d-%H%M%S')
    name  = example.metadata[:full_description][0..60].parameterize
    path  = dir.join("#{name}-#{stamp}.png")

    page.save_screenshot(path.to_s) # rubocop:disable Lint/Debugger
    RSpec.configuration.reporter.message("Saved screenshot: #{path}")
  end
end
