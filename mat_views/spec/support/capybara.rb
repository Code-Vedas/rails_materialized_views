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

setup_with_selenium_manager

Capybara.server = :puma, { Silent: true }
Capybara.default_max_wait_time = ENV.fetch('CAPYBARA_WAIT_TIME', 6).to_i
Capybara.match = :smart
Capybara.ignore_hidden_elements = true

Capybara.default_driver = :selenium_headless
Capybara.javascript_driver = :selenium_headless
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
