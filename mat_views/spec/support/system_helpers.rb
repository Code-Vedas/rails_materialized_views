# frozen_string_literal: true

# spec/support/system_helpers.rb

module SystemHelpers
  def visit_dashboard(locale: 'en')
    visit "/mat_views/#{locale}/admin"
  end

  def reload_page
    page.execute_script('window.location.reload()')
  end

  def open_runs
    find('a[data-testid="runs_tab_link"]').click
    wait_for_turbo_idle
  end

  def open_definitions
    find('a[data-testid="definitions_tab_link"]').click
    wait_for_turbo_idle
  end
end

RSpec.configure do |config|
  config.include SystemHelpers, type: :feature
end
