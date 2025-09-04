# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.
RSpec.describe 'Runs', type: :feature do
  let!(:definition) { create(:mat_view_definition, name: 'mv_test', schedule_cron: '0 * * * *') }

  before do
    visit_dashboard
  end

  def check_run_row(id, operation, mat_view_name, status, duration, started_at, row_count)
    within("tr[data-testid='RUN_ROW_#{id}']") do
      expect(page).to have_css('td.mv-td', text: operation)
      expect(page).to have_css('td.mv-td', text: mat_view_name)
      expect(page).to have_css('td.mv-td', text: status)
      expect(page).to have_css('td.mv-td', text: duration)
      expect(page).to have_css('td.mv-td', text: started_at)
      expect(page).to have_css('td.mv-td', text: row_count)
      expect(page).to have_css('td.mv-td a', text: 'View details')
    end
  end

  describe 'Filters', :js do
    scenario 'All filters present' do
      open_runs
      within_turbo_frame('dash-runs') do
        expect(page).to have_select('mat_view_definition_id', options: ['All definitions', 'mv_test'])
        expect(page).to have_select('operation', options: ['All operations', 'Create', 'Refresh', 'Drop'])
        expect(page).to have_select('status', options: ['All statuses', 'Running', 'Success', 'Failed'])
      end
    end

    scenario 'Have reset button' do
      open_runs
      within_turbo_frame('dash-runs') do
        expect(page).to have_css("a[data-testid='reset_filters_link']")
      end
    end

    scenario 'Reset button clears all filters' do
      open_runs
      within_turbo_frame('dash-runs') do
        expect(page).to have_select('mat_view_definition_id', options: ['All definitions', 'mv_test'])
        expect(page).to have_select('operation', options: ['All operations', 'Create', 'Refresh', 'Drop'])
        expect(page).to have_select('status', options: ['All statuses', 'Running', 'Success', 'Failed'])

        find('select[name="operation"]').find(:option, 'Create').select_option
        wait_for_turbo_idle
        expect(page).to have_current_path(/operation=create/)
        expect(page).to have_select('operation', selected: 'Create')

        find('select[name="status"]').find(:option, 'Success').select_option
        wait_for_turbo_idle
        expect(page).to have_current_path(/operation=create&status=success/)
        expect(page).to have_select('status', selected: 'Success')

        find('select[name="mat_view_definition_id"]').find(:option, 'mv_test').select_option
        wait_for_turbo_idle
        expect(page).to have_current_path(/operation=create&status=success&mat_view_definition_id=#{definition.id}/)
        expect(page).to have_select('mat_view_definition_id', selected: 'mv_test')

        find("a[data-testid='reset_filters_link']").click
        wait_for_turbo_idle
        expect(page).to have_current_path(/tab=runs/)
        expect(page).to have_select('mat_view_definition_id', selected: 'All definitions')
        expect(page).to have_select('operation', selected: 'All operations')
        expect(page).to have_select('status', selected: 'All statuses')
      end
    end

    context 'when switching away from runs tab', :js do
      scenario 'status filter resets' do
        open_runs
        within_turbo_frame('dash-runs') do
          expect(page).to have_css('table.mv-table tbody tr.mv-tr td.mv-td', text: 'No runs found.')
          find('select[name="status"]').find(:option, 'Success').select_option
          wait_for_turbo_idle
          expect(page).to have_current_path(/status=success/)
          expect(page).to have_css('table.mv-table tbody tr.mv-tr td.mv-td', text: 'No runs found for the selected filters.')
        end

        open_definitions
        expect(page).to have_current_path(/tab=definitions/)
        within_turbo_frame('dash-definitions') do
          expect(page).to have_css('table.mv-table tr', text: definition.name)
          expect(page).to have_css('table.mv-table tr', text: 'Regular')
          expect(page).to have_css('table.mv-table tr', text: '0 * * * *')
        end

        open_runs
        within_turbo_frame('dash-runs') do
          expect(page).to have_current_path(/tab=runs/)
          expect(page).to have_select('status', selected: 'All statuses')
          expect(page).to have_css('table.mv-table tbody tr.mv-tr td.mv-td', text: 'No runs found.')
        end
      end

      scenario 'operation filter resets' do
        open_runs
        within_turbo_frame('dash-runs') do
          expect(page).to have_css('table.mv-table tbody tr.mv-tr td.mv-td', text: 'No runs found.')
          find('select[name="operation"]').find(:option, 'Create').select_option
          wait_for_turbo_idle
          expect(page).to have_current_path(/operation=create/)
          expect(page).to have_css('table.mv-table tbody tr.mv-tr td.mv-td', text: 'No runs found for the selected filters.')
        end

        open_definitions
        expect(page).to have_current_path(/tab=definitions/)
        within_turbo_frame('dash-definitions') do
          expect(page).to have_css('table.mv-table tr', text: definition.name)
          expect(page).to have_css('table.mv-table tr', text: 'Regular')
          expect(page).to have_css('table.mv-table tr', text: '0 * * * *')
        end

        open_runs
        within_turbo_frame('dash-runs') do
          expect(page).to have_current_path(/tab=runs/)
          expect(page).to have_select('operation', selected: 'All operations')
          expect(page).to have_css('table.mv-table tbody tr.mv-tr td.mv-td', text: 'No runs found.')
        end
      end

      scenario 'mat_view_definition_id filter resets' do
        open_runs
        within_turbo_frame('dash-runs') do
          expect(page).to have_css('table.mv-table tbody tr.mv-tr td.mv-td', text: 'No runs found.')
          find('select[name="operation"]').find(:option, 'Create').select_option
          wait_for_turbo_idle
          expect(page).to have_current_path(/operation=create/)
          find('select[name="status"]').find(:option, 'Success').select_option
          wait_for_turbo_idle
          expect(page).to have_current_path(/operation=create&status=success/)
          expect(page).to have_select('mat_view_definition_id', options: ['All definitions', 'mv_test'])
          find('select[name="mat_view_definition_id"]').find(:option, 'mv_test').select_option
          wait_for_turbo_idle
          expect(page).to have_current_path(/operation=create&status=success&mat_view_definition_id=#{definition.id}/)
          expect(page).to have_css('table.mv-table tbody tr.mv-tr td.mv-td', text: 'No runs found for the selected filters.')
        end

        open_definitions
        expect(page).to have_current_path(/tab=definitions/)
        within_turbo_frame('dash-definitions') do
          expect(page).to have_css('table.mv-table tr', text: definition.name)
          expect(page).to have_css('table.mv-table tr', text: 'Regular')
          expect(page).to have_css('table.mv-table tr', text: '0 * * * *')
        end

        open_runs
        within_turbo_frame('dash-runs') do
          expect(page).to have_current_path(/tab=runs/)
          expect(page).to have_select('mat_view_definition_id', selected: 'All definitions')
          expect(page).to have_select('operation', selected: 'All operations')
          expect(page).to have_select('status', selected: 'All statuses')
          expect(page).to have_css('table.mv-table tbody tr.mv-tr td.mv-td', text: 'No runs found.')
        end
      end

      scenario 'all filters reset when switching to definitions and back' do
        open_runs
        within_turbo_frame('dash-runs') do
          expect(page).to have_css('table.mv-table tbody tr.mv-tr td.mv-td', text: 'No runs found.')
          # expand the mat view definition filter to have 2 options
          expect(page).to have_select('mat_view_definition_id', options: ['All definitions', 'mv_test'])
          find('select[name="mat_view_definition_id"]').find(:option, 'mv_test').select_option
          wait_for_turbo_idle
          expect(page).to have_current_path(/mat_view_definition_id=#{definition.id}/)
          expect(page).to have_css('table.mv-table tbody tr.mv-tr td.mv-td', text: 'No runs found for the selected filters.')
        end

        open_definitions
        expect(page).to have_current_path(/tab=definitions/)
        within_turbo_frame('dash-definitions') do
          expect(page).to have_css('table.mv-table tr', text: definition.name)
          expect(page).to have_css('table.mv-table tr', text: 'Regular')
          expect(page).to have_css('table.mv-table tr', text: '0 * * * *')
        end

        open_runs
        within_turbo_frame('dash-runs') do
          expect(page).to have_current_path(/tab=runs/)
          expect(page).to have_select('mat_view_definition_id', selected: 'All definitions')
          expect(page).to have_css('table.mv-table tbody tr.mv-tr td.mv-td', text: 'No runs found.')
        end
      end
    end
  end

  context 'when no runs exist', :js do
    scenario 'View empty state' do
      open_runs
      within_turbo_frame('dash-runs') do
        expect(page).to have_css('table.mv-table tbody tr.mv-tr td.mv-td', text: 'No runs found.')
      end
    end

    scenario 'Operations filter with no results' do
      open_runs
      within_turbo_frame('dash-runs') do
        expect(page).to have_css('table.mv-table tbody tr.mv-tr td.mv-td', text: 'No runs found.')
        find('select[name="operation"]').find(:option, 'Create').select_option
        wait_for_turbo_idle
        expect(page).to have_current_path(/operation=create/)
        expect(page).to have_css('table.mv-table tbody tr.mv-tr td.mv-td', text: 'No runs found for the selected filters.')

        # reload and check filter persists
        reload_page
        wait_for_turbo_idle
        expect(page).to have_current_path(/operation=create/)
        expect(page).to have_select('operation', selected: 'Create')
        expect(page).to have_css('table.mv-table tbody tr.mv-tr td.mv-td', text: 'No runs found for the selected filters.')
      end
    end

    scenario 'Status filter with no results' do
      open_runs
      within_turbo_frame('dash-runs') do
        expect(page).to have_css('table.mv-table tbody tr.mv-tr td.mv-td', text: 'No runs found.')
        find('select[name="status"]').find(:option, 'Success').select_option
        wait_for_turbo_idle
        expect(page).to have_current_path(/status=success/)
        expect(page).to have_css('table.mv-table tbody tr.mv-tr td.mv-td', text: 'No runs found for the selected filters.')

        # reload and check filter persists
        reload_page
        wait_for_turbo_idle
        expect(page).to have_current_path(/status=success/)
        expect(page).to have_select('status', selected: 'Success')
        expect(page).to have_css('table.mv-table tbody tr.mv-tr td.mv-td', text: 'No runs found for the selected filters.')
      end
    end

    scenario 'Mat view definition filter with no results' do
      open_runs
      within_turbo_frame('dash-runs') do
        expect(page).to have_css('table.mv-table tbody tr.mv-tr td.mv-td', text: 'No runs found.')
        find('select[name="mat_view_definition_id"]').find(:option, 'mv_test').select_option
        wait_for_turbo_idle
        expect(page).to have_current_path(/mat_view_definition_id=#{definition.id}/)
        expect(page).to have_css('table.mv-table tbody tr.mv-tr td.mv-td', text: 'No runs found for the selected filters.')

        # reload and check filter persists
        reload_page
        wait_for_turbo_idle
        expect(page).to have_current_path(/mat_view_definition_id=#{definition.id}/)
        expect(page).to have_select('mat_view_definition_id', selected: 'mv_test')
        expect(page).to have_css('table.mv-table tbody tr.mv-tr td.mv-td', text: 'No runs found for the selected filters.')
      end
    end

    scenario 'All filters together with no results' do
      open_runs
      within_turbo_frame('dash-runs') do
        expect(page).to have_css('table.mv-table tbody tr.mv-tr td.mv-td', text: 'No runs found.')
        find('select[name="operation"]').find(:option, 'Create').select_option
        wait_for_turbo_idle
        expect(page).to have_current_path(/operation=create/)
        find('select[name="status"]').find(:option, 'Success').select_option
        wait_for_turbo_idle
        expect(page).to have_current_path(/operation=create&status=success/)
        expect(page).to have_select('mat_view_definition_id', options: ['All definitions', 'mv_test'])
        find('select[name="mat_view_definition_id"]').find(:option, 'mv_test').select_option
        wait_for_turbo_idle
        expect(page).to have_current_path(/operation=create&status=success&mat_view_definition_id=#{definition.id}/)
        expect(page).to have_css('table.mv-table tbody tr.mv-tr td.mv-td', text: 'No runs found for the selected filters.')

        # reload and check filter persists
        reload_page
        wait_for_turbo_idle
        expect(page).to have_current_path(/operation=create&status=success&mat_view_definition_id=#{definition.id}/)
        expect(page).to have_select('mat_view_definition_id', selected: 'mv_test')
        expect(page).to have_select('operation', selected: 'Create')
        expect(page).to have_select('status', selected: 'Success')
        expect(page).to have_css('table.mv-table tbody tr.mv-tr td.mv-td', text: 'No runs found for the selected filters.')
      end
    end
  end

  context 'when runs exist', :js do
    let!(:other_defn) { create(:mat_view_definition, name: 'mv_other', sql: 'SELECT 1 AS id') }
    let!(:create_success_run) do
      create(:mat_view_run,
             mat_view_definition: definition,
             operation: :create,
             status: :success,
             finished_at: 10.minutes.ago,
             meta: { response: { row_count_before: 100, row_count_after: 122 } },
             duration_ms: 10)
    end
    let!(:refresh_failed_run) do
      create(:mat_view_run,
             mat_view_definition: definition,
             operation: :refresh,
             finished_at: 10.minutes.ago,
             status: :failed,
             duration_ms: 20,
             error: { message: 'Refresh failed',
                      class: 'StandardError',
                      backtrace: [] })
    end
    let!(:refresh_running_run) { create(:mat_view_run, mat_view_definition: definition, operation: :refresh, status: :running) }
    let!(:drop_success_run) do
      create(:mat_view_run,
             mat_view_definition: definition,
             operation: :drop,
             status: :success,
             meta: { response: { row_count_before: 122, row_count_after: 0 } },
             duration_ms: 5)
    end

    scenario 'View all runs' do
      open_runs
      within_turbo_frame('dash-runs') do
        expect(page).to have_css('table.mv-table tbody tr.mv-tr', count: 4)
        within('table.mv-table tbody') do
          check_run_row(create_success_run.id, 'Create', 'mv_test', 'Success', '10 ms',
                        I18n.l(create_success_run.started_at.in_time_zone, format: :datetime12hour), '100/122')
          check_run_row(refresh_failed_run.id, 'Refresh', 'mv_test', 'Failed', '20 ms',
                        I18n.l(refresh_failed_run.started_at.in_time_zone, format: :datetime12hour), '-/-')
          check_run_row(refresh_running_run.id, 'Refresh', 'mv_test', 'Running', '-',
                        I18n.l(refresh_running_run.started_at.in_time_zone, format: :datetime12hour), '-/-')
          check_run_row(drop_success_run.id, 'Drop', 'mv_test', 'Success', '5 ms',
                        I18n.l(drop_success_run.started_at.in_time_zone, format: :datetime12hour), '122/0')
        end
      end
    end

    scenario 'Filter by operation' do
      open_runs
      within_turbo_frame('dash-runs') do
        expect(page).to have_css('table.mv-table tbody tr.mv-tr', count: 4)

        find('select[name="operation"]').find(:option, 'Create').select_option
        wait_for_turbo_idle
        expect(page).to have_current_path(/operation=create/)
        expect(page).to have_css('table.mv-table tbody tr.mv-tr', count: 1)
        check_run_row(create_success_run.id, 'Create', 'mv_test', 'Success', '10 ms',
                      I18n.l(create_success_run.started_at.in_time_zone, format: :datetime12hour), '100/122')

        find('select[name="operation"]').find(:option, 'Refresh').select_option
        wait_for_turbo_idle
        expect(page).to have_current_path(/operation=refresh/)
        expect(page).to have_css('table.mv-table tbody tr.mv-tr', count: 2)
        check_run_row(refresh_failed_run.id, 'Refresh', 'mv_test', 'Failed', '20 ms',
                      I18n.l(refresh_failed_run.started_at.in_time_zone, format: :datetime12hour), '-/-')
        check_run_row(refresh_running_run.id, 'Refresh', 'mv_test', 'Running', '-',
                      I18n.l(refresh_running_run.started_at.in_time_zone, format: :datetime12hour), '-/-')

        find('select[name="operation"]').find(:option, 'Drop').select_option
        wait_for_turbo_idle
        expect(page).to have_current_path(/operation=drop/)
        expect(page).to have_css('table.mv-table tbody tr.mv-tr', count: 1)
        check_run_row(drop_success_run.id, 'Drop', 'mv_test', 'Success', '5 ms',
                      I18n.l(drop_success_run.started_at.in_time_zone, format: :datetime12hour), '122/0')
      end
    end

    scenario 'Filter by status' do
      open_runs
      within_turbo_frame('dash-runs') do
        expect(page).to have_css('table.mv-table tbody tr.mv-tr', count: 4)

        find('select[name="status"]').find(:option, 'Success').select_option
        wait_for_turbo_idle
        expect(page).to have_current_path(/status=success/)
        expect(page).to have_css('table.mv-table tbody tr.mv-tr', count: 2)
        check_run_row(create_success_run.id, 'Create', 'mv_test', 'Success', '10 ms',
                      I18n.l(create_success_run.started_at.in_time_zone, format: :datetime12hour), '100/122')
        check_run_row(drop_success_run.id, 'Drop', 'mv_test', 'Success', '5 ms',
                      I18n.l(drop_success_run.started_at.in_time_zone, format: :datetime12hour), '122/0')

        find('select[name="status"]').find(:option, 'Failed').select_option
        wait_for_turbo_idle
        expect(page).to have_current_path(/status=failed/)
        expect(page).to have_css('table.mv-table tbody tr.mv-tr', count: 1)
        check_run_row(refresh_failed_run.id, 'Refresh', 'mv_test', 'Failed', '20 ms',
                      I18n.l(refresh_failed_run.started_at.in_time_zone, format: :datetime12hour), '-/-')

        find('select[name="status"]').find(:option, 'Running').select_option
        wait_for_turbo_idle
        expect(page).to have_current_path(/status=running/)
        expect(page).to have_css('table.mv-table tbody tr.mv-tr', count: 1)
        check_run_row(refresh_running_run.id, 'Refresh', 'mv_test', 'Running', '-',
                      I18n.l(refresh_running_run.started_at.in_time_zone, format: :datetime12hour), '-/-')
      end
    end

    scenario 'Filter by mat view definition' do
      open_runs
      within_turbo_frame('dash-runs') do
        expect(page).to have_css('table.mv-table tbody tr.mv-tr', count: 4)

        find('select[name="mat_view_definition_id"]').find(:option, 'mv_test').select_option
        wait_for_turbo_idle
        expect(page).to have_current_path(/mat_view_definition_id=#{definition.id}/)
        expect(page).to have_css('table.mv-table tbody tr.mv-tr', count: 4)
        check_run_row(create_success_run.id, 'Create', 'mv_test', 'Success', '10 ms',
                      I18n.l(create_success_run.started_at.in_time_zone, format: :datetime12hour), '100/122')
        check_run_row(refresh_failed_run.id, 'Refresh', 'mv_test', 'Failed', '20 ms',
                      I18n.l(refresh_failed_run.started_at.in_time_zone, format: :datetime12hour), '-/-')
        check_run_row(refresh_running_run.id, 'Refresh', 'mv_test', 'Running', '-',
                      I18n.l(refresh_running_run.started_at.in_time_zone, format: :datetime12hour), '-/-')
        check_run_row(drop_success_run.id, 'Drop', 'mv_test', 'Success', '5 ms',
                      I18n.l(drop_success_run.started_at.in_time_zone, format: :datetime12hour), '122/0')

        find('select[name="mat_view_definition_id"]').find(:option, 'mv_other').select_option
        wait_for_turbo_idle
        expect(page).to have_current_path(/mat_view_definition_id=#{other_defn.id}/)
        expect(page).to have_css('table.mv-table tbody tr.mv-tr td.mv-td', text: 'No runs found for the selected filters.')
      end
    end

    scenario 'Filter by all filters together' do
      open_runs
      within_turbo_frame('dash-runs') do
        expect(page).to have_css('table.mv-table tbody tr.mv-tr', count: 4)

        find('select[name="operation"]').find(:option, 'Refresh').select_option
        wait_for_turbo_idle
        expect(page).to have_current_path(/operation=refresh/)
        expect(page).to have_css('table.mv-table tbody tr.mv-tr', count: 2)

        find('select[name="status"]').find(:option, 'Failed').select_option
        wait_for_turbo_idle
        expect(page).to have_current_path(/operation=refresh&status=failed/)
        expect(page).to have_css('table.mv-table tbody tr.mv-tr', count: 1)
        check_run_row(refresh_failed_run.id, 'Refresh', 'mv_test', 'Failed', '20 ms',
                      I18n.l(refresh_failed_run.started_at.in_time_zone, format: :datetime12hour), '-/-')

        find('select[name="mat_view_definition_id"]').find(:option, 'mv_test').select_option
        wait_for_turbo_idle
        expect(page).to have_current_path(/operation=refresh&status=failed&mat_view_definition_id=#{definition.id}/)
        expect(page).to have_css('table.mv-table tbody tr.mv-tr', count: 1)
        check_run_row(refresh_failed_run.id, 'Refresh', 'mv_test', 'Failed', '20 ms',
                      I18n.l(refresh_failed_run.started_at.in_time_zone, format: :datetime12hour), '-/-')

        find('select[name="mat_view_definition_id"]').find(:option, 'mv_other').select_option
        wait_for_turbo_idle
        expect(page).to have_current_path(/operation=refresh&status=failed&mat_view_definition_id=#{other_defn.id}/)
        expect(page).to have_css('table.mv-table tbody tr.mv-tr td.mv-td', text: 'No runs found for the selected filters.')
      end
    end

    scenario 'View run details: failed' do
      open_runs
      open_drawer(
        click_selector: "a[data-testid='view_link-run-#{refresh_failed_run.id}']",
        within_selector: 'turbo-frame#dash-runs',
        form_selector: 'turbo-frame#mv-drawer'
      )

      within_drawer do
        within('div.mv-field', text: /Definition/) do
          expect(page).to have_css('div.mv-label', text: 'Definition')
          expect(page).to have_css('div.mv-label + div', text: 'mv_test')
        end

        within('div.mv-field', text: /Operation/) do
          expect(page).to have_css('div.mv-label', text: 'Operation')
          expect(page).to have_css('div.mv-label + div', text: 'Refresh')
        end

        within('div.mv-field', text: /Started at/) do
          expect(page).to have_css('div.mv-label', text: 'Started at')
          expect(page).to have_css('div.mv-label + div', text: I18n.l(refresh_failed_run.started_at&.in_time_zone, format: :datetime12hour))
        end

        within('div.mv-field', text: /Finished at/) do
          expect(page).to have_css('div.mv-label', text: 'Finished at')
          expect(page).to have_css('div.mv-label + div', text: I18n.l(refresh_failed_run.finished_at&.in_time_zone, format: :datetime12hour))
        end

        within('div.mv-field', text: /Status/) do
          expect(page).to have_css('div.mv-label', text: 'Status')
          expect(page).to have_css('div.mv-label + div', text: 'Failed')
        end

        within('div.mv-field', text: /Duration/) do
          expect(page).to have_css('div.mv-label', text: 'Duration (ms)')
          expect(page).to have_css('div.mv-label + div', text: '20 ms')
        end

        within('div.mv-field', text: /Row count before/) do
          expect(page).to have_css('div.mv-label', text: 'Row count before')
          expect(page).to have_css('div.mv-label + div', text: '-')
        end

        within('div.mv-field', text: /Row count after/) do
          expect(page).to have_css('div.mv-label', text: 'Row count after')
          expect(page).to have_css('div.mv-label + div', text: '-')
        end

        within('div.mv-field details', text: /Error/) do
          expect(page).to have_css('summary div.mv-label', text: 'Error')
          expect(JSON.parse(find('div pre').text.strip)).to eq('class' => 'StandardError', 'message' => 'Refresh failed', 'backtrace' => [])
        end

        within('div.mv-field details', text: /Metadata/) do
          expect(page).to have_css('summary div.mv-label', text: 'Metadata')
          expect(page).to have_css('div pre', text: '{}')
        end
      end
    end

    scenario 'View run details: success' do
      open_runs
      within_turbo_frame('dash-runs') do
        expect(page).to have_css('table.mv-table tbody tr.mv-tr', count: 4)
      end
      open_drawer(
        click_selector: "a[data-testid='view_link-run-#{create_success_run.id}']",
        within_selector: 'turbo-frame#dash-runs',
        form_selector: 'turbo-frame#mv-drawer'
      )

      within_drawer do
        within('div.mv-field', text: /Definition/) do
          expect(page).to have_css('div.mv-label', text: 'Definition')
          expect(page).to have_css('div.mv-label + div', text: 'mv_test')
        end

        within('div.mv-field', text: /Operation/) do
          expect(page).to have_css('div.mv-label', text: 'Operation')
          expect(page).to have_css('div.mv-label + div', text: 'Create')
        end

        within('div.mv-field', text: /Started at/) do
          expect(page).to have_css('div.mv-label', text: 'Started at')
          expect(page).to have_css('div.mv-label + div', text: I18n.l(create_success_run.started_at&.in_time_zone, format: :datetime12hour))
        end

        within('div.mv-field', text: /Finished at/) do
          expect(page).to have_css('div.mv-label', text: 'Finished at')
          expect(page).to have_css('div.mv-label + div', text: I18n.l(create_success_run.finished_at&.in_time_zone, format: :datetime12hour))
        end

        within('div.mv-field', text: /Status/) do
          expect(page).to have_css('div.mv-label', text: 'Status')
          expect(page).to have_css('div.mv-label + div', text: 'Success')
        end

        within('div.mv-field', text: /Duration/) do
          expect(page).to have_css('div.mv-label', text: 'Duration (ms)')
          expect(page).to have_css('div.mv-label + div', text: '10 ms')
        end

        within('div.mv-field', text: /Row count before/) do
          expect(page).to have_css('div.mv-label', text: 'Row count before')
          expect(page).to have_css('div.mv-label + div', text: '100')
        end

        within('div.mv-field', text: /Row count after/) do
          expect(page).to have_css('div.mv-label', text: 'Row count after')
          expect(page).to have_css('div.mv-label + div', text: '122')
        end

        expect(page).to have_no_css('div.mv-field', text: /Error/)

        within('div.mv-field details', text: /Meta/) do
          expect(page).to have_css('summary div.mv-label', text: 'Meta')
          json = JSON.parse(find('div pre').text.strip)
          expect(json).to eq('response' => { 'row_count_before' => 100, 'row_count_after' => 122 })
        end
      end
    end
  end
end
