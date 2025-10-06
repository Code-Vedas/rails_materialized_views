# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

RSpec.describe 'Datatable', :feature do
  feature 'Datatable UI' do
    background { visit_dashboard }

    context 'when all features are enabled', :js do
      scenario 'shows all options in the Actions menu', :js do
        create_list(:mat_view_definition, 21) # rubocop:disable FactoryBot/ExcessiveCreateList

        visit_dashboard
        wait_for_turbo_idle

        within_turbo_frame('dash-definitions') do
          # search box
          expect(page).to have_css("input[data-testid='dt_search_input-mv-definitions-table-search']")
          expect(page).to have_css("button[data-testid='dt_clear_search_btn-mv-definitions-table-clear-search']")

          # filter by selects
          expect(page).to have_css("select[data-testid='mv-definitions-table-dt_filter_select-name']")
          expect(page).to have_css("select[data-testid='mv-definitions-table-dt_filter_select-refresh_strategy']")
          expect(page).to have_css("select[data-testid='mv-definitions-table-dt_filter_select-schedule_cron']")

          # sort buttons
          expect(page).to have_css("button[data-testid='toggle_sort_button-mv-definitions-table-name']")
          expect(page).to have_css("button[data-testid='toggle_sort_button-mv-definitions-table-refresh_strategy']")
          expect(page).to have_css("button[data-testid='toggle_sort_button-mv-definitions-table-schedule_cron']")
          expect(page).to have_css("button[data-testid='toggle_sort_button-mv-definitions-table-last_run_at']")

          # scroll to bottom to see pagination
          execute_script('window.scrollTo(0, document.body.scrollHeight);')

          # pagination buttons
          expect(page).to have_css("button[data-testid='dt_pagination_btn-mv-definitions-table-page-first']")
          expect(page).to have_css("button[data-testid='dt_pagination_btn-mv-definitions-table-page-previous']")
          expect(page).to have_css("button[data-testid='dt_pagination_btn-mv-definitions-table-page-next']")
          expect(page).to have_css("button[data-testid='dt_pagination_btn-mv-definitions-table-page-last']")
          expect(page).to have_css("button[data-testid='dt_pagination_btn-mv-definitions-table-page-1']")
          expect(page).to have_css("button[data-testid='dt_pagination_btn-mv-definitions-table-page-2']")
          expect(page).to have_css("button[data-testid='dt_pagination_btn-mv-definitions-table-page-3']")

          # per page select
          expect(page).to have_css("select[data-testid='dt_pagination_btn-mv-definitions-table-per-page']")
        end
      end
    end

    context 'when some features are disabled', :js do
      let(:controller) { MatViews::Admin::MatViewDefinitionsController }

      before do
        create_list(:mat_view_definition, 10)
      end

      context 'when searching is disabled' do
        before do
          # rubocop:disable RSpec/AnyInstance
          allow_any_instance_of(controller).to receive(:index_dt_config).and_wrap_original do |method, *args|
            config = method.call(*args)
            config[:search_enabled] = false
            config
          end
          # rubocop:enable RSpec/AnyInstance
        end

        scenario 'does not show search box', :js do
          visit_dashboard
          wait_for_turbo_idle

          within_turbo_frame('dash-definitions') do
            expect(page).to have_no_css("input[data-testid='dt_search_input-mv-definitions-table-search']")
            expect(page).to have_no_css("button[data-testid='dt_clear_search_btn-mv-definitions-table-clear-search']")
          end
        end
      end

      context 'when filtering is disabled' do
        before do
          # rubocop:disable RSpec/AnyInstance
          allow_any_instance_of(controller).to receive(:index_dt_config).and_wrap_original do |method, *args|
            config = method.call(*args)
            config[:filter_enabled] = false
            config
          end
          # rubocop:enable RSpec/AnyInstance
        end

        scenario 'does not show filter selects', :js do
          visit_dashboard
          wait_for_turbo_idle

          within_turbo_frame('dash-definitions') do
            expect(page).to have_no_css("select[data-testid='mv-definitions-table-dt_filter_select-name']")
            expect(page).to have_no_css("select[data-testid='mv-definitions-table-dt_filter_select-refresh_strategy']")
            expect(page).to have_no_css("select[data-testid='mv-definitions-table-dt_filter_select-schedule_cron']")
          end
        end
      end

      context 'when sorting is disabled' do
        before do
          # rubocop:disable RSpec/AnyInstance
          allow_any_instance_of(controller).to receive(:index_dt_config).and_wrap_original do |method, *args|
            config = method.call(*args)
            columns = config[:columns]
            columns.each do |col, col_item|
              col_item[:sort] = nil
              columns[col] = col_item
            end
            config[:columns] = columns
            config
          end
          # rubocop:enable RSpec/AnyInstance
        end

        scenario 'does not show sort buttons', :js do
          visit_dashboard
          wait_for_turbo_idle

          within_turbo_frame('dash-definitions') do
            expect(page).to have_no_css("button[data-testid='toggle_sort_button-mv-definitions-table-name']")
            expect(page).to have_no_css("button[data-testid='toggle_sort_button-mv-definitions-table-refresh_strategy']")
            expect(page).to have_no_css("button[data-testid='toggle_sort_button-mv-definitions-table-schedule_cron']")
            expect(page).to have_no_css("button[data-testid='toggle_sort_button-mv-definitions-table-last_run_at']")
          end
        end
      end
    end

    context 'when no features are enabled', :js do
      let(:controller) { MatViews::Admin::MatViewDefinitionsController }

      before do
        create_list(:mat_view_definition, 10)

        # rubocop:disable RSpec/AnyInstance
        allow_any_instance_of(controller).to receive(:index_dt_config).and_wrap_original do |method, *args|
          config = method.call(*args)
          config[:search_enabled] = false
          config[:filter_enabled] = false
          columns = config[:columns]
          columns.each do |col, col_item|
            col_item[:sort] = nil
            columns[col] = col_item
          end
          config[:columns] = columns
          config
        end
        # rubocop:enable RSpec/AnyInstance
      end

      scenario 'shows no datatable controls', :js do
        visit_dashboard
        wait_for_turbo_idle

        within_turbo_frame('dash-definitions') do
          # search box
          expect(page).to have_no_css("input[data-testid='dt_search_input-mv-definitions-table-search']")
          expect(page).to have_no_css("button[data-testid='dt_clear_search_btn-mv-definitions-table-clear-search']")

          # filter by selects
          expect(page).to have_no_css("select[data-testid='mv-definitions-table-dt_filter_select-name']")
          expect(page).to have_no_css("select[data-testid='mv-definitions-table-dt_filter_select-refresh_strategy']")
          expect(page).to have_no_css("select[data-testid='mv-definitions-table-dt_filter_select-schedule_cron']")

          # sort buttons
          expect(page).to have_no_css("button[data-testid='toggle_sort_button-mv-definitions-table-name']")
          expect(page).to have_no_css("button[data-testid='toggle_sort_button-mv-definitions-table-refresh_strategy']")
          expect(page).to have_no_css("button[data-testid='toggle_sort_button-mv-definitions-table-schedule_cron']")
          expect(page).to have_no_css("button[data-testid='toggle_sort_button-mv-definitions-table-last_run_at']")
        end
      end
    end
  end

  feature 'Datatable sorting' do
    scenario 'sorts columns when sort buttons are clicked', :js do
      create(:mat_view_definition, name: 'C_View')
      create(:mat_view_definition, name: 'A_View')
      create(:mat_view_definition, name: 'B_View')

      visit_dashboard
      wait_for_turbo_idle

      # scroll to bottom
      execute_script('window.scrollTo(0, document.body.scrollHeight);')

      within_turbo_frame('dash-definitions') do
        # Initial order should be as created
        expect(all('tbody tr')[0]).to have_content('C_View') # rubocop:disable Capybara/FindAllFirst
        expect(all('tbody tr')[1]).to have_content('A_View')
        expect(all('tbody tr')[2]).to have_content('B_View')
        within('button[data-testid="toggle_sort_button-mv-definitions-table-name"]') do
          expect(page).to have_css('svg.mv-icon.muted.sort-neutral')
          expect(page).to have_css('svg.mv-icon.active.sort-asc.hidden', visible: :all)
          expect(page).to have_css('svg.mv-icon.active.sort-desc.hidden', visible: :all)
        end

        # Click to sort by name ascending
        find("button[data-testid='toggle_sort_button-mv-definitions-table-name']").click
        wait_for_turbo_idle

        # expect url to have dtsort param
        expect(URI.parse(current_url).query).to include('dtsort=name:asc')
        within('button[data-testid="toggle_sort_button-mv-definitions-table-name"]') do
          expect(page).to have_css('svg.mv-icon.muted.sort-neutral.hidden', visible: :all)
          expect(page).to have_css('svg.mv-icon.active.sort-asc')
          expect(page).to have_css('svg.mv-icon.active.sort-desc.hidden', visible: :all)
        end

        expect(all('tbody tr')[0]).to have_content('A_View') # rubocop:disable Capybara/FindAllFirst
        expect(all('tbody tr')[1]).to have_content('B_View')
        expect(all('tbody tr')[2]).to have_content('C_View')

        # Click to sort by name descending
        find("button[data-testid='toggle_sort_button-mv-definitions-table-name']").click
        wait_for_turbo_idle

        expect(URI.parse(current_url).query).to include('dtsort=name:desc')
        within('button[data-testid="toggle_sort_button-mv-definitions-table-name"]') do
          expect(page).to have_css('svg.mv-icon.muted.sort-neutral.hidden', visible: :all)
          expect(page).to have_css('svg.mv-icon.active.sort-asc.hidden', visible: :all)
          expect(page).to have_css('svg.mv-icon.active.sort-desc')
        end

        expect(all('tbody tr')[0]).to have_content('C_View') # rubocop:disable Capybara/FindAllFirst
        expect(all('tbody tr')[1]).to have_content('B_View')
        expect(all('tbody tr')[2]).to have_content('A_View')

        # Click to remove sorting
        find("button[data-testid='toggle_sort_button-mv-definitions-table-name']").click
        wait_for_turbo_idle

        expect(URI.parse(current_url).query).not_to include('dtsort=')
        within('button[data-testid="toggle_sort_button-mv-definitions-table-name"]') do
          expect(page).to have_css('svg.mv-icon.muted.sort-neutral')
          expect(page).to have_css('svg.mv-icon.active.sort-asc.hidden', visible: :all)
          expect(page).to have_css('svg.mv-icon.active.sort-desc.hidden', visible: :all)
        end
        # Order should revert to initial
        expect(all('tbody tr')[0]).to have_content('C_View') # rubocop:disable Capybara/FindAllFirst
        expect(all('tbody tr')[1]).to have_content('A_View')
        expect(all('tbody tr')[2]).to have_content('B_View')
      end
    end
  end

  feature 'Datatable filtering' do
    scenario 'filters rows when filter selects are changed', :js do
      create(:mat_view_definition, name: 'View_One', refresh_strategy: 'regular')
      create(:mat_view_definition, name: 'View_Two', refresh_strategy: 'swap')
      create(:mat_view_definition, name: 'View_Three', refresh_strategy: 'regular')

      visit_dashboard
      wait_for_turbo_idle

      # scroll to bottom
      execute_script('window.scrollTo(0, document.body.scrollHeight);')

      within_turbo_frame('dash-definitions') do
        within('table.mv-table.with-filters tbody') do
          # Initial state shows all rows
          expect(page).to have_content('View_One')
          expect(page).to have_content('View_Two')
          expect(page).to have_content('View_Three')
        end

        # Filter by refresh_strategy = 'regular'
        find("select[data-testid='mv-definitions-table-dt_filter_select-refresh_strategy']").select('Regular')
        wait_for_turbo_idle

        # url should have dtfilter param and Regular selected
        expect(URI.parse(current_url).query).to include('dtfilter=refresh_strategy:regular')
        expect(find("select[data-testid='mv-definitions-table-dt_filter_select-refresh_strategy']").value).to eq('regular')

        within('table.mv-table.with-filters tbody') do
          expect(page).to have_content('View_One')
          expect(page).to have_content('View_Three')
          expect(page).to have_no_content('View_Two')
        end

        # Change filter to refresh_strategy = 'swap'
        find("select[data-testid='mv-definitions-table-dt_filter_select-refresh_strategy']").select('Swap')
        wait_for_turbo_idle

        # url should have dtfilter param and Swap selected
        expect(URI.parse(current_url).query).to include('dtfilter=refresh_strategy:swap')
        expect(find("select[data-testid='mv-definitions-table-dt_filter_select-refresh_strategy']").value).to eq('swap')

        within('table.mv-table.with-filters tbody') do
          expect(page).to have_content('View_Two')
          expect(page).to have_no_content('View_One')
          expect(page).to have_no_content('View_Three')
        end

        # Reset filter to show all
        find("select[data-testid='mv-definitions-table-dt_filter_select-refresh_strategy']").select('Any ( no filter )')
        wait_for_turbo_idle

        # url should not have dtfilter param
        expect(URI.parse(current_url).query).not_to include('dtfilter=')
        expect(find("select[data-testid='mv-definitions-table-dt_filter_select-refresh_strategy']").value).to eq('no_filter')

        within('table.mv-table.with-filters tbody') do
          expect(page).to have_content('View_One')
          expect(page).to have_content('View_Two')
          expect(page).to have_content('View_Three')
        end
      end
    end
  end

  feature 'Datatable searching' do
    scenario 'filters rows when search input is used', :js do
      create(:mat_view_definition, name: 'First_View')
      create(:mat_view_definition, name: 'Second_View')
      create(:mat_view_definition, name: 'Third_View')

      visit_dashboard
      wait_for_turbo_idle

      # scroll to bottom
      execute_script('window.scrollTo(0, document.body.scrollHeight);')

      within_turbo_frame('dash-definitions') do
        within('table.mv-table.with-filters tbody') do
          # Initial state shows all rows
          expect(page).to have_content('First_View')
          expect(page).to have_content('Second_View')
          expect(page).to have_content('Third_View')
        end

        # Search for 'Second'
        input = find("input[data-testid='dt_search_input-mv-definitions-table-search']", visible: :all)
        input.set('Second')
        # wait for debounce
        wait_for_turbo_idle
        sleep 1
        wait_for_turbo_idle

        # url should have dtsearch param
        expect(URI.parse(current_url).query).to include('dtsearch=Second')

        within('table.mv-table.with-filters tbody') do
          expect(page).to have_content('Second_View')
          expect(page).to have_no_content('First_View')
          expect(page).to have_no_content('Third_View')
        end

        # Clear search
        find("button[data-testid='dt_clear_search_btn-mv-definitions-table-clear-search']").click
        wait_for_turbo_idle

        # url should not have dtsearch param
        expect(URI.parse(current_url).query).not_to include('dtsearch=')

        within('table.mv-table.with-filters tbody') do
          expect(page).to have_content('First_View')
          expect(page).to have_content('Second_View')
          expect(page).to have_content('Third_View')
        end
      end
    end
  end

  feature 'Datatable pagination' do
    scenario 'navigates pages when pagination buttons are clicked', :js do
      create_list(:mat_view_definition, 25) # rubocop:disable FactoryBot/ExcessiveCreateList

      visit_dashboard
      wait_for_turbo_idle

      # scroll to bottom
      execute_script('window.scrollTo(0, document.body.scrollHeight);')

      within_turbo_frame('dash-definitions') do
        expect(page).to have_css("button[data-testid='dt_pagination_btn-mv-definitions-table-page-first']")
        expect(page).to have_css("button[data-testid='dt_pagination_btn-mv-definitions-table-page-previous']")
        expect(page).to have_css("button[data-testid='dt_pagination_btn-mv-definitions-table-page-next']")
        expect(page).to have_css("button[data-testid='dt_pagination_btn-mv-definitions-table-page-last']")
        expect(page).to have_css("button[data-testid='dt_pagination_btn-mv-definitions-table-page-1']")
        expect(page).to have_css("button[data-testid='dt_pagination_btn-mv-definitions-table-page-2']")
        expect(page).to have_css("button[data-testid='dt_pagination_btn-mv-definitions-table-page-3']")

        # first, previous is inactive and go to last page
        expect(find("button[data-testid='dt_pagination_btn-mv-definitions-table-page-first']")[:disabled]).to eq('true')
        expect(find("button[data-testid='dt_pagination_btn-mv-definitions-table-page-previous']")[:disabled]).to eq('true')
        find("button[data-testid='dt_pagination_btn-mv-definitions-table-page-last']").click
        wait_for_turbo_idle
        expect(URI.parse(current_url).query).to include('dtpage=3')
        # 5 tbody tr
        expect(all('tbody tr').size).to eq(5)

        # next and last are inactive and go to first page
        expect(find("button[data-testid='dt_pagination_btn-mv-definitions-table-page-next']")[:disabled]).to eq('true')
        expect(find("button[data-testid='dt_pagination_btn-mv-definitions-table-page-last']")[:disabled]).to eq('true')
        find("button[data-testid='dt_pagination_btn-mv-definitions-table-page-first']").click
        wait_for_turbo_idle
        expect(URI.parse(current_url).query).to include('dtpage=1')
        # 10 tbody tr
        expect(all('tbody tr').size).to eq(10)

        # go to page 2, first, previous, next, last are active
        find("button[data-testid='dt_pagination_btn-mv-definitions-table-page-2']").click
        wait_for_turbo_idle
        expect(find("button[data-testid='dt_pagination_btn-mv-definitions-table-page-first']")[:disabled]).to eq('false')
        expect(find("button[data-testid='dt_pagination_btn-mv-definitions-table-page-previous']")[:disabled]).to eq('false')
        expect(find("button[data-testid='dt_pagination_btn-mv-definitions-table-page-next']")[:disabled]).to eq('false')
        expect(find("button[data-testid='dt_pagination_btn-mv-definitions-table-page-last']")[:disabled]).to eq('false')
        expect(URI.parse(current_url).query).to include('dtpage=2')
        # 10 tbody tr
        expect(all('tbody tr').size).to eq(10)
      end
    end
  end
end
