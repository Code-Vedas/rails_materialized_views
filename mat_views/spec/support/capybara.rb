# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

require 'capybara/rails'
require 'capybara/rspec'
require 'selenium/webdriver'
require 'support/screenshot_helpers'

def setup_with_selenium_manager
  driver = Selenium::WebDriver.for(:firefox)
  driver.get('https://www.selenium.dev/documentation/selenium_manager/')
  driver.quit
end

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
  setup_with_selenium_manager
  Capybara.default_driver = :firefox_headless
  Capybara.javascript_driver = :firefox_headless
end

Capybara.disable_animation = true

RSpec.configure do |config|
  config.include ScreenshotHelpers, :feature
  config.include ScreenshotHelpers, :feature_app_screenshots
  config.include Capybara::DSL, :feature
  config.include Capybara::RSpecMatchers, :feature
  config.include Capybara::DSL, :feature_app_screenshots
  config.include Capybara::RSpecMatchers,  :feature_app_screenshots

  %i[feature feature_app_screenshots].each do |type|
    config.after(type: type) do |example|
      save_failure_screenshot(example)
    end
  end
end
