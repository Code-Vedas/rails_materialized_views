# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

RSpec.describe 'I18n & URL', type: :feature do
  before { visit_dashboard }

  scenario 'Dashboard path includes locale', :js do
    wait_for_turbo_idle
    expect(page).to have_current_path('/mat_views/en-US/admin', ignore_query: true)
  end

  scenario 'Locale redirect to chosen locale', :js do
    visit('/mat_views/fr/admin')
    wait_for_turbo_idle
    expect(page).to have_current_path('/mat_views/en-US/admin', ignore_query: true)
  end
end
