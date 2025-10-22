# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

# Helpers for system tests (feature specs).
module SystemHelpers
  def visit_dashboard
    visit '/mat_views/en-US/admin'
  end

  def reload_page
    page.execute_script('window.location.reload()')
  end

  def open_runs
    expect(page).to have_css('a[data-testid="runs_tab_link"]', wait: Capybara.default_max_wait_time)
    find('a[data-testid="runs_tab_link"]').click
    wait_for_turbo_idle
  end

  def open_definitions
    expect(page).to have_css('a[data-testid="definitions_tab_link"]', wait: Capybara.default_max_wait_time)
    find('a[data-testid="definitions_tab_link"]').click
    wait_for_turbo_idle
  end
end

RSpec.configure do |config|
  config.include SystemHelpers, :feature
  config.include SystemHelpers, :feature_app_screenshots
end
