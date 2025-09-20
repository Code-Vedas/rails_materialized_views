# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

RSpec.describe 'Preferences', type: :feature do
  before { visit_dashboard }

  let(:lang_options) do
    [
      'Aussie (Ocker)',
      'English (Australia)',
      'Børk! Børk! Børk!',
      'English (Canada)',
      'English (United Kingdom)',
      'English (India)',
      'Pirate English (Arrr!)',
      'English (United States)'
    ]
  end

  shared_examples 'change theme' do |theme_before, theme_after|
    scenario "Change to from #{theme_before} to #{theme_after}", :js do
      expect(page).to have_css("html[data-theme='#{theme_before}']")
      open_preferences
      within_drawer do
        expect(page).to have_css('div.mv-label', text: 'Theme')
        expect(page).to have_field('theme', type: 'radio', with: 'auto', checked: theme_before == 'auto')
        expect(page).to have_field('theme', type: 'radio', with: 'light', checked: theme_before == 'light')
        expect(page).to have_field('theme', type: 'radio', with: 'dark', checked: theme_before == 'dark')

        find("input[type='radio'][value='#{theme_after}']").click
        find('button[data-testid="preferences_save_button"]').click
      end

      wait_for_turbo_idle

      expect(page).to have_css("html[data-theme='#{theme_after}']")

      open_preferences
      within_drawer do
        expect(page).to have_css('div.mv-label', text: 'Theme')
        expect(page).to have_field('theme', type: 'radio', with: 'auto', checked: theme_after == 'auto')
        expect(page).to have_field('theme', type: 'radio', with: 'light', checked: theme_after == 'light')
        expect(page).to have_field('theme', type: 'radio', with: 'dark', checked: theme_after == 'dark')
      end
    end
  end

  shared_examples 'change language' do |lang_before, lang_after, language_txt_before, language_txt_after|
    scenario "Change language from #{lang_before} to #{lang_after}", :js do
      open_preferences
      within_drawer do
        expect(page).to have_css('label.mv-label', text: language_txt_before)
        expect(page).to have_select('locale', options: lang_options, selected: lang_before)
        select(lang_after, from: 'locale')
        find('button[data-testid="preferences_save_button"]').click
      end
      wait_for_turbo_idle

      open_preferences
      within_drawer do
        expect(page).to have_css('label.mv-label', text: language_txt_after)
        expect(page).to have_select('locale', options: lang_options, selected: lang_after)
      end
    end
  end

  scenario 'Open Preferences in drawer', :js do
    open_preferences

    within_drawer do
      expect(page).to have_css('div.mv-label', text: 'Theme')
      expect(page).to have_field('theme', type: 'radio', with: 'auto', checked: true)
      expect(page).to have_field('theme', type: 'radio', with: 'light')
      expect(page).to have_field('theme', type: 'radio', with: 'dark')

      expect(page).to have_css('label.mv-label', text: 'Language')
      expect(page).to have_select('locale', options: lang_options, selected: 'English (United States)')
    end
  end

  describe 'Change Theme', :js do
    it_behaves_like 'change theme', 'auto', 'light'
    it_behaves_like 'change theme', 'auto', 'dark'
    it_behaves_like 'change theme', 'auto', 'auto'
  end

  describe 'Change Language', :js do
    it_behaves_like 'change language', 'English (United States)', 'Aussie (Ocker)', 'Language', 'Lingo'
    it_behaves_like 'change language', 'English (United States)', 'English (Australia)', 'Language', 'Language'
    it_behaves_like 'change language', 'English (United States)', 'Børk! Børk! Børk!', 'Language', 'Lengoeege-a'
    it_behaves_like 'change language', 'English (United States)', 'English (Canada)', 'Language', 'Language'
    it_behaves_like 'change language', 'English (United States)', 'English (United Kingdom)', 'Language', 'Language'
    it_behaves_like 'change language', 'English (United States)', 'English (India)', 'Language', 'Language'
    it_behaves_like 'change language', 'English (United States)', 'English (United States)', 'Language', 'Language'
    it_behaves_like 'change language', 'English (United States)', 'Pirate English (Arrr!)', 'Language', 'Tongue'
  end
end
