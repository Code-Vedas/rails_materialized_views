# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.
RSpec.describe 'UI screenshots', type: :feature do
  let(:screenshot_dir) { Rails.root.join('tmp', 'app-screenshots') }
  let(:langs) { ['English (United States)', 'English (Canada)', 'Aussie (Ocker)'] }
  let(:lang_map) do
    {
      'English (United States)' => 'en-US',
      'English (Canada)' => 'en-CA',
      'Aussie (Ocker)' => 'en-AU-ocker'
    }
  end
  let(:themes) { %w[light dark] }
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
           error: { message: 'Refresh failed',
                    class: 'StandardError',
                    backtrace: [] },
           duration_ms: 10)
  end

  let(:urls) do
    [
      {
        name: 'Definitions List',
        url: '/mat_views/:lang/admin'
      },
      {
        name: 'Definitions View',
        url: "/mat_views/:lang/admin?open=definitions_view_#{example_definition.id}",
        wait_for_drawer: true
      },
      {
        name: 'Definitions Edit',
        url: "/mat_views/:lang/admin?open=definitions_edit_#{example_definition.id}",
        wait_drawer_open: true
      },
      {
        name: 'Runs List',
        url: '/mat_views/:lang/admin?tab=runs'
      },
      {
        name: 'Runs View',
        url: "/mat_views/:lang/admin?tab=runs&open=runs_view_#{example_run.id}",
        wait_drawer_open: true
      },
      {
        name: 'Preferences',
        url: '/mat_views/:lang/admin?open=preferences_edit',
        wait_drawer_open: true
      }
    ]
  end

  before do
    FileUtils.rm_rf(screenshot_dir)
    FileUtils.mkdir_p(screenshot_dir)

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

  def visit_url_and_take_screenshot(name, url, wait_drawer_open, lang, theme)
    visit_dashboard
    wait_for_turbo_idle
    select_language(lang)
    wait_for_turbo_idle
    select_theme(theme)
    wait_for_turbo_idle
    visit url
    wait_for_turbo_idle
    wait_drawer_open(timeout: 10) if wait_drawer_open

    FileUtils.mkdir_p(screenshot_dir.join(lang_map[lang], theme.downcase))
    filename = screenshot_dir.join(lang_map[lang], theme.downcase, "#{name.downcase.tr(' ', '_')}.png").to_s

    page.save_screenshot(filename) # rubocop:disable Lint/Debugger
  end

  it 'takes screenshots for various pages, languages and themes', :js do
    langs.each do |lang|
      themes.each do |theme|
        urls.each do |url_info|
          url = url_info[:url].gsub(':lang', lang_map[lang])
          expect { visit_url_and_take_screenshot(url_info[:name], url, url_info[:wait_drawer_open], lang, theme) }.not_to raise_error
        end
      end
    end
  end
end
