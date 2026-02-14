# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

RSpec.describe 'UI screenshots', :feature_app_screenshots do
  let!(:example_definition) do
    create(:mat_view_definition, name: 'mv_test', sql: 'SELECT 1 AS id', schedule_cron: '0 * * * *')
  end

  let!(:example_run) do
    create(:mat_view_run,
           mat_view_definition: example_definition,
           operation: :create,
           status: :failed,
           finished_at: 10.minutes.ago,
           meta: { response: { row_count_before: 100, row_count_after: 122 } },
           error: { message: 'Refresh failed', class: 'StandardError', backtrace: [] },
           duration_ms: 10)
  end

  before do
    create(:mat_view_definition, name: 'mv_other', sql: 'SELECT 1 AS id', refresh_strategy: :swap)

    create(:mat_view_run,
           mat_view_definition: example_definition,
           operation: :refresh,
           finished_at: 10.minutes.ago,
           status: :success,
           duration_ms: 20,
           meta: { response: { row_count_before: 100, row_count_after: 122 } })

    create(:mat_view_run, mat_view_definition: example_definition, operation: :refresh, status: :running)

    visit_dashboard
  end

  def visit_url_and_take_screenshot(lang_name, lang_code, url, wait_drawer_open, name, theme)
    screenshot_dir = Rails.root.join('tmp', 'app-screenshots')
    visit_dashboard
    wait_for_turbo_idle
    select_language(lang_name)
    wait_for_turbo_idle
    select_theme(theme)
    wait_for_turbo_idle

    visit url
    wait_for_turbo_idle
    wait_drawer_open(timeout: 10) if wait_drawer_open

    dir = screenshot_dir.join(lang_code, theme.downcase)
    FileUtils.mkdir_p(dir)
    filename = dir.join("#{name.downcase.tr(' ', '_')}.png").to_s

    page.save_screenshot(filename) # rubocop:disable Lint/Debugger
  end

  lang_code_env = ENV.fetch('SCREENSHOT_LANG', nil)
  locales = if lang_code_env.nil? || lang_code_env.strip.downcase == 'all'
              MatViews::Engine.available_locales.map(&:to_s)
            else
              [lang_code_env.strip]
            end

  locales.each do |lang_code|
    # rubocop:disable RSpec/LeakyLocalVariable
    lang_name = MatViews::Engine.locale_code_mapping[lang_code.to_sym]
    # rubocop:enable RSpec/LeakyLocalVariable

    %w[light dark].freeze.each do |theme|
      it "captures screenshots for #{lang_name} (#{lang_code}) in #{theme} theme", :js do
        urls = [
          { name: 'Definitions List', url: "/mat_views/#{lang_code}/admin" },
          { name: 'Definitions View',
            url: "/mat_views/#{lang_code}/admin?open=definitions_view_#{example_definition.id}",
            wait_drawer_open: true },
          { name: 'Definitions New',
            url: "/mat_views/#{lang_code}/admin?open=definitions_new",
            wait_drawer_open: true },
          { name: 'Definitions Edit',
            url: "/mat_views/#{lang_code}/admin?open=definitions_edit_#{example_definition.id}",
            wait_drawer_open: true },
          { name: 'Runs List', url: "/mat_views/#{lang_code}/admin?tab=runs" },
          { name: 'Runs View',
            url: "/mat_views/#{lang_code}/admin?tab=runs&open=runs_view_#{example_run.id}",
            wait_drawer_open: true },
          { name: 'Preferences',
            url: "/mat_views/#{lang_code}/admin?open=preferences_edit",
            wait_drawer_open: true }
        ]

        urls.each do |info|
          expect do
            visit_url_and_take_screenshot(
              lang_name,
              lang_code,
              info[:url],
              info[:wait_drawer_open],
              info[:name],
              theme
            )
          end.not_to raise_error
        end
      end
    end
  end
end
