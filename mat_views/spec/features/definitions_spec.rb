# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

RSpec.describe 'Definitions', :feature do
  before { visit_dashboard }

  feature 'New Definition' do
    scenario 'opens the New Definition form in a drawer', :js do
      open_drawer(
        click_selector: 'a[data-testid="new_definition_link"]',
        within_selector: 'turbo-frame#dash-definitions'
      )

      within_drawer do
        expect(page).to have_field('Name')
        expect(page).to have_field('SQL (SELECT ...)')
        expect(page).to have_select('Refresh strategy')
        expect(page).to have_css('button[data-testid="submit_button-defn-new"]')
        expect(page).to have_css('button[data-testid="cancel_button-defn-new"]')
      end
    end

    scenario 'closes the drawer when Cancel is clicked', :js do
      open_drawer(
        click_selector: 'a[data-testid="new_definition_link"]',
        within_selector: 'turbo-frame#dash-definitions'
      )
      within_drawer do
        expect(page).to have_field('Name')
        find('button[data-testid="cancel_button-defn-new"]').click
      end
      wait_drawer_closed
      wait_for_turbo_idle

      expect(page).to have_no_css('div.mv-drawer-root.is-open')
    end

    scenario 'creates a valid definition', :js do
      open_drawer(
        click_selector: 'a[data-testid="new_definition_link"]',
        within_selector: 'turbo-frame#dash-definitions'
      )

      name = "sales_mv_#{uniq_token}"

      within_drawer do
        fill_in 'Name', with: name
        fill_in 'SQL (SELECT ...)', with: 'SELECT 1 AS id'
        select 'Regular', from: 'Refresh strategy'
        fill_in 'Schedule (cron)', with: '0 * * * *'
        fill_in 'Unique index columns', with: 'id'
        fill_in 'Dependencies', with: 'sales'
        find('button[data-testid="submit_button-defn-new"]').click
      end

      wait_drawer_closed
      wait_for_turbo_idle

      within_turbo_frame('dash-definitions') do
        expect(page).to have_css('table.mv-table tr', text: name)
        expect(page).to have_css('table.mv-table tr', text: 'Regular')
        expect(page).to have_css('table.mv-table tr', text: '0 * * * *')
      end
    end

    scenario 'shows validation errors in the drawer', :js do
      open_drawer(
        click_selector: 'a[data-testid="new_definition_link"]',
        within_selector: 'turbo-frame#dash-definitions'
      )

      within_drawer do
        fill_in 'Name', with: 'invalid name' # invalid (space)
        fill_in 'SQL (SELECT ...)', with: 'Update 1 AS id' # invalid (not SELECT)
        find('button[data-testid="submit_button-defn-new"]').click
      end

      wait_for_turbo_idle

      # Flash may render inside the drawer or globally; check either place.
      if page.has_css?('turbo-frame#mv-drawer .mv-flash.mv-flash--err')
        within_turbo_frame('mv-drawer') do
          expect(page).to have_css('.mv-flash.mv-flash--err')
          expect(page).to have_text('Name is not a valid PostgreSQL identifier')
          expect(page).to have_text('SQL (SELECT ...) must start with SELECT')
        end
      else
        expect(page).to have_css('.mv-flash.mv-flash--err')
        within('.mv-flash.mv-flash--err') do
          expect(page).to have_text('Name is not a valid PostgreSQL identifier')
          expect(page).to have_text('SQL (SELECT ...) must start with SELECT')
        end
      end
    end
  end

  feature 'View Definition' do
    scenario 'views a definition in a drawer', :js do
      defn = create(:mat_view_definition,
                    name: "products_mv_#{uniq_token}",
                    refresh_strategy: 'swap',
                    schedule_cron: '30 2 * * 1',
                    unique_index_columns: %w[id sku],
                    dependencies: %w[products categories],
                    sql: 'SELECT 1 AS id')

      visit_dashboard
      wait_for_turbo_idle

      open_drawer(
        click_selector: "a[data-testid='view_link-defn-#{defn.id}']",
        within_selector: 'turbo-frame#dash-definitions',
        form_selector: 'turbo-frame#mv-drawer'
      )

      within_drawer do
        within('div.mv-field', text: /Refresh strategy/) do
          expect(page).to have_css('div.mv-label', text: 'Refresh strategy')
          expect(page).to have_css('div.mv-label + div', text: 'Swap')
        end

        within('div.mv-field', text: /Schedule \(cron\)/) do
          expect(page).to have_css('div.mv-label', text: 'Schedule (cron)')
          expect(page).to have_css('div.mv-label + div', text: '30 2 * * 1')
        end

        within('div.mv-field', text: /Unique index columns/) do
          expect(page).to have_css('div.mv-label', text: 'Unique index columns')
          expect(page).to have_css('div.mv-label + div', text: 'id, sku')
        end

        within('div.mv-field', text: /Dependencies/) do
          expect(page).to have_css('div.mv-label', text: 'Dependencies')
          expect(page).to have_css('div.mv-label + div', text: 'products, categories')
        end

        within('div.mv-field', text: /Last run/) do
          expect(page).to have_css('div.mv-label', text: 'Last run')
          expect(page).to have_css('div.mv-label + div', text: '-')
        end
        expect(page).to have_css('div.mv-details__content pre', text: 'SELECT 1 AS id')
        expect(page).to have_css("a[data-testid='edit_link-defn-#{defn.id}']")
        expect(page).to have_css("button[data-testid='delete_link-defn-#{defn.id}']")
      end
    end
  end

  feature 'Edit Definition (from drawer)' do
    scenario 'edits a definition in the stacked drawer and shows the updates', :js do
      defn = create(:mat_view_definition, name: 'edit_me', sql: 'SELECT 1 AS id')

      visit_dashboard
      wait_for_turbo_idle

      # Open view pane
      open_drawer(
        click_selector: "a[data-testid='view_link-defn-#{defn.id}']",
        within_selector: 'turbo-frame#dash-definitions',
        form_selector: 'turbo-frame#mv-drawer'
      )

      # Switch to edit form inside drawer
      open_drawer(
        click_selector: "a[data-testid='edit_link-defn-#{defn.id}']",
        within_selector: 'turbo-frame#mv-drawer',
        form_selector: 'turbo-frame#mv-drawer form'
      )

      within_drawer do
        fill_in 'SQL (SELECT ...)', with: 'SELECT 2 AS id'
        find("button[data-testid='submit_button-defn-#{defn.id}']").click
      end

      wait_for_turbo_idle

      within_drawer do
        expect(page).to have_text('SELECT 2 AS id')
      end
    end
  end

  feature 'Edit Definition (from table row)' do
    scenario 'edits a definition via the table row and shows the updates', :js do
      defn = create(:mat_view_definition, name: 'edit_me_table', sql: 'SELECT 1 AS id')

      visit_dashboard
      wait_for_turbo_idle

      open_drawer(
        click_selector: "a[data-testid='edit_link-defn-#{defn.id}']",
        within_selector: 'turbo-frame#dash-definitions',
        form_selector: 'turbo-frame#mv-drawer form'
      )

      within_drawer do
        fill_in 'Name', with: 'edit_me_table_edited'
        fill_in 'SQL (SELECT ...)', with: 'SELECT 2 AS id'
        find("button[data-testid='submit_button-defn-#{defn.id}']").click
      end

      wait_drawer_closed

      within_turbo_frame('dash-definitions') do
        expect(page).to have_css('table.mv-table tr', text: 'edit_me_table_edited')
        click_link 'edit_me_table_edited'
      end

      within_drawer do
        expect(page).to have_text('SELECT 2 AS id')
      end
    end
  end

  feature 'Delete Definition (from drawer)' do
    scenario 'deletes the definition when confirming', :js do
      defn = create(:mat_view_definition, name: 'delete_me', sql: 'SELECT 1 AS id')

      visit_dashboard
      wait_for_turbo_idle

      open_drawer(
        click_selector: "a[data-testid='view_link-defn-#{defn.id}']",
        within_selector: 'turbo-frame#dash-definitions',
        form_selector: 'turbo-frame#mv-drawer'
      )

      within_drawer do
        find("button[data-testid='delete_link-defn-#{defn.id}']").click
      end

      accept_mv_confirm
      wait_drawer_closed
      wait_for_turbo_idle

      within_turbo_frame('dash-definitions') do
        expect(page).to have_no_css('table.mv-table tr', text: 'delete_me')
      end
    end

    scenario 'keeps the definition when canceling', :js do
      defn = create(:mat_view_definition, name: 'dont_delete_me', sql: 'SELECT 1 AS id')

      visit_dashboard
      wait_for_turbo_idle

      open_drawer(
        click_selector: "a[data-testid='view_link-defn-#{defn.id}']",
        within_selector: 'turbo-frame#dash-definitions',
        form_selector: 'turbo-frame#mv-drawer'
      )

      within_drawer do
        find("button[data-testid='delete_link-defn-#{defn.id}']").click
      end

      reject_mv_confirm
      wait_for_turbo_idle

      within_turbo_frame('dash-definitions') do
        expect(page).to have_css('table.mv-table tr', text: 'dont_delete_me')
      end
    end
  end

  feature 'Delete Definition (from table row)' do
    scenario 'deletes the definition when confirming', :js do
      defn = create(:mat_view_definition, name: 'delete_me_table', sql: 'SELECT 1 AS id')

      visit_dashboard
      wait_for_turbo_idle

      within_turbo_frame('dash-definitions') do
        find("button[data-testid='delete_link-defn-#{defn.id}']").click
      end

      accept_mv_confirm
      wait_for_turbo_idle

      within_turbo_frame('dash-definitions') do
        expect(page).to have_no_css('table.mv-table tr', text: 'delete_me_table')
      end
    end

    scenario 'keeps the definition when canceling', :js do
      defn = create(:mat_view_definition, name: 'dont_delete_me_table', sql: 'SELECT 1 AS id')

      visit_dashboard
      wait_for_turbo_idle

      within_turbo_frame('dash-definitions') do
        find("button[data-testid='delete_link-defn-#{defn.id}']").click
      end

      reject_mv_confirm
      wait_for_turbo_idle

      within_turbo_frame('dash-definitions') do
        expect(page).to have_css('table.mv-table tr', text: 'dont_delete_me_table')
      end
    end
  end

  feature 'History Link' do
    scenario 'navigates to the Runs page', :js do
      defn = create(:mat_view_definition, name: 'history_link_mv', sql: 'SELECT 1 AS id')

      visit_dashboard
      wait_for_turbo_idle

      within_turbo_frame('dash-definitions') do
        find("a[data-testid='view_history_link-defn-#{defn.id}']").click
      end

      wait_for_turbo_idle

      expect(page).to have_current_path("/mat_views/en/admin?dtfilter=definition:#{defn.id}&tab=runs&dtpage=1&dtperpage=10")
      expect(page).to have_select('definition', selected: defn.name)
    end
  end
end
