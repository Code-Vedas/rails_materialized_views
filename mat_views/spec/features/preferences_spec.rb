# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

RSpec.describe 'Preferences', type: :feature do
  before { visit_dashboard }

  let(:lang_options) do
    MatViews::Engine.locale_code_mapping.values.sort
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
      select_language(lang_before)
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
      expect(page).to have_select('locale', options: lang_options, selected: 'English')
    end
  end

  describe 'Change Theme', :js do
    it_behaves_like 'change theme', 'auto', 'light'
    it_behaves_like 'change theme', 'auto', 'dark'
    it_behaves_like 'change theme', 'auto', 'auto'
  end

  describe 'Change Language', :js do
    all_locales = MatViews::Engine.locale_code_mapping.to_a

    locale_pair = all_locales.sample(2)
    lang_code_before, lang_code_after = locale_pair.map { |e| e[0] }
    lang_name_before, lang_name_after = locale_pair.map { |e| e[1] }
    language_txt_before = I18n.t('mat_views.settings.language', locale: lang_code_before)
    language_txt_after = I18n.t('mat_views.settings.language', locale: lang_code_after)
    it_behaves_like 'change language', lang_name_before, lang_name_after, language_txt_before, language_txt_after
    it_behaves_like 'change language', lang_name_after, lang_name_before, language_txt_after, language_txt_before
  end
end
