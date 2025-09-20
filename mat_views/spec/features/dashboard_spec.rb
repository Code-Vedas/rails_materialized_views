# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

RSpec.describe 'Dashboard', type: :feature do
  feature 'Dashboard UI' do
    background { visit_dashboard }

    scenario 'displays the header with logo and title' do
      expect(page).to have_link(href: '/mat_views/en/admin', class: 'mv-brand', count: 1)

      within("a.mv-brand[href='/mat_views/en/admin']") do
        expect(page).to have_css("img.mv-logo[alt='MatViews Admin']")
        expect(page).to have_css('span', text: 'MatViews Admin')
      end
    end

    scenario 'shows the banner with signed-in user email' do
      expect(page).to have_css('div.row-item span', text: /Signed in as .+@.+\..+/)
    end

    scenario 'opens Preferences in a drawer when clicking the gear icon', :js do
      expect(page).to have_css('div.row-item a[data-drawer-title="Preferences"]')
      expect(page).to have_css('div.row-item a[data-action="click->drawer#open"]')

      find('div.row-item a[data-drawer-title="Preferences"]').click
      expect(page).to have_css('h2#mv-drawer-title', text: /Preferences/i, wait: 5)
    end

    scenario 'shows the Definitions tab active and the Runs tab available', :js do
      expect(page).to have_css('nav.mv-tabs')
      within('nav.mv-tabs') do
        expect(page).to have_css('a.mv-tab.mv-tab--on', text: 'Definitions', exact_text: true)
        expect(page).to have_css('a.mv-tab', text: 'Runs', exact_text: true)
      end

      expect(page).to have_css(
        'div[data-tabs-target="panel"][data-name="definitions"] turbo-frame#dash-definitions',
        visible: :all
      )
      expect(page).to have_css(
        'div[data-tabs-target="panel"][data-name="runs"][hidden] turbo-frame#dash-runs',
        visible: :all
      )
    end
  end
end
