# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

RSpec.describe 'Drawer behaviour', :feature do
  before do
    create(:mat_view_definition, name: "sales_mv_#{uniq_token}", sql: 'SELECT 1 AS id')
    visit_dashboard
  end

  scenario 'opens and closes drawer, form cancel', :js do
    open_drawer(
      click_selector: 'a[data-testid="new_definition_link"]',
      within_selector: 'turbo-frame#dash-definitions'
    )

    within_drawer do
      expect(page).to have_css('button[data-testid="cancel_button-defn-new"]')
      find('button[data-testid="cancel_button-defn-new"]').click
    end

    wait_drawer_closed
    wait_for_turbo_idle

    expect(page).to have_no_css('div.mv-drawer-root.is-open')
  end

  scenario 'opens and closes drawer, outside click', :js do
    open_drawer(
      click_selector: 'a[data-testid="new_definition_link"]',
      within_selector: 'turbo-frame#dash-definitions'
    )

    within_drawer do
      expect(page).to have_css('button[data-testid="cancel_button-defn-new"]')
    end

    # click outside the drawer to close
    find('div.mv-drawer-overlay').click

    wait_drawer_closed
    wait_for_turbo_idle

    expect(page).to have_no_css('div.mv-drawer-root.is-open')
  end

  scenario 'opens and closes drawer, ESC key', :js do
    open_drawer(
      click_selector: 'a[data-testid="new_definition_link"]',
      within_selector: 'turbo-frame#dash-definitions'
    )

    within_drawer do
      expect(page).to have_css('button[data-testid="cancel_button-defn-new"]')
    end

    find('body').send_keys(:escape)

    wait_drawer_closed
    wait_for_turbo_idle

    expect(page).to have_no_css('div.mv-drawer-root.is-open')
  end

  scenario 'opens and closes drawer, close button', :js do
    open_drawer(
      click_selector: 'a[data-testid="new_definition_link"]',
      within_selector: 'turbo-frame#dash-definitions'
    )

    within_drawer do
      expect(page).to have_css('button[data-testid="cancel_button-defn-new"]')
    end

    expect(page).to have_css('button[data-testid="drawer_close_link"]')
    find('button[data-testid="drawer_close_link"]').click

    wait_drawer_closed
    wait_for_turbo_idle

    expect(page).to have_no_css('div.mv-drawer-root.is-open')
  end

  scenario 'Stacked drawers open and close back to previous', :js do
    defn = create(:mat_view_definition, name: "products_mv_#{uniq_token}", sql: 'SELECT 1 AS id')

    visit_dashboard
    wait_for_turbo_idle

    open_drawer(
      click_selector: "a[data-testid='view_link-defn-#{defn.id}']",
      within_selector: 'turbo-frame#dash-definitions',
      form_selector: 'turbo-frame#mv-drawer'
    )
    wait_for_turbo_idle

    within_drawer do
      expect(page).to have_css("a[data-testid='edit_link-defn-#{defn.id}']")
      find("a[data-testid='edit_link-defn-#{defn.id}']").click
    end

    wait_for_turbo_idle

    within_drawer do
      expect(page).to have_css("button[data-testid='submit_button-defn-#{defn.id}']")
      expect(page).to have_css("button[data-testid='cancel_button-defn-#{defn.id}']")
      find("button[data-testid='cancel_button-defn-#{defn.id}']").click
    end

    wait_for_turbo_idle

    within_drawer do
      expect(page).to have_css("button[data-testid='delete_link-defn-#{defn.id}']")
      expect(page).to have_css("a[data-testid='edit_link-defn-#{defn.id}']")
    end

    wait_for_turbo_idle

    find('div.mv-drawer-overlay').click

    wait_drawer_closed
    wait_for_turbo_idle

    expect(page).to have_no_css('div.mv-drawer-root.is-open')
  end

  scenario 'Refresh button reloads drawer content', :js do
    defn = create(:mat_view_definition, name: "products_mv_#{uniq_token}", sql: 'SELECT 1 AS id')
    visit_dashboard
    wait_for_turbo_idle
    open_drawer(
      click_selector: "a[data-testid='view_link-defn-#{defn.id}']",
      within_selector: 'turbo-frame#dash-definitions',
      form_selector: 'turbo-frame#mv-drawer'
    )
    wait_for_turbo_idle

    expect(page).to have_css('h2#mv-drawer-title', text: defn.name)

    within_drawer do
      expect(page).to have_css('div.mv-details__content pre', text: 'SELECT 1 AS id')
    end

    defn.update(name: "edit_me_table_#{uniq_token}", sql: 'SELECT 2 AS id')
    defn.reload

    find('button[data-testid="drawer_refresh_link"]').click

    expect(page).to have_css('h2#mv-drawer-title', text: defn.name)
    within_drawer do
      expect(page).to have_css('div.mv-details__content pre', text: 'SELECT 2 AS id')
    end
  end
end
