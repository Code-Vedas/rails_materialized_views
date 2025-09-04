# frozen_string_literal: true

require 'securerandom'

module TurboHelpers
  def uniq_token(len = 3)
    SecureRandom.hex(len)
  end

  def wait_for_turbo_idle(timeout: Capybara.default_max_wait_time)
    expect(page).to have_no_css('turbo-stream[action]', wait: timeout)
    expect(page).to have_no_css('turbo-frame[busy]', wait: timeout)
  end

  def wait_frame_ready(selector = 'turbo-frame#mv-drawer', timeout: Capybara.default_max_wait_time)
    expect(page).to have_css(selector, wait: timeout, visible: :all)
    expect(page).to have_no_css("#{selector}[busy]", wait: timeout)
  end

  def open_drawer(click_selector:, within_selector: nil,
                  form_selector: 'turbo-frame#mv-drawer form',
                  timeout: Capybara.default_max_wait_time)
    if within_selector
      within(within_selector) { find(click_selector, wait: timeout).click }
    else
      find(click_selector, wait: timeout).click
    end

    expect(page).to have_css('div.mv-drawer-root.is-open', wait: timeout)
    wait_frame_ready('turbo-frame#mv-drawer', timeout: timeout)
    expect(page).to have_css(form_selector, wait: timeout, visible: :all)
  end

  def within_drawer(timeout: Capybara.default_max_wait_time, &)
    wait_frame_ready('turbo-frame#mv-drawer', timeout: timeout)
    within('turbo-frame#mv-drawer', &)
  end

  def within_turbo_frame(frame_id, timeout: Capybara.default_max_wait_time, &)
    wait_frame_ready("turbo-frame##{frame_id}", timeout: timeout)
    within("turbo-frame##{frame_id}", &)
  end

  def wait_drawer_closed(timeout: Capybara.default_max_wait_time)
    wait_for_turbo_idle(timeout: timeout)
    expect(page).to have_no_css('div.mv-drawer-root.is-open', wait: timeout)
  end

  def accept_mv_confirm(timeout: Capybara.default_max_wait_time)
    expect(page).to have_css('#mv-confirm', wait: timeout)
    within('#mv-confirm') { click_button('Yes') }
    wait_for_turbo_idle(timeout: timeout)
  end

  def reject_mv_confirm(timeout: Capybara.default_max_wait_time)
    expect(page).to have_css('#mv-confirm', wait: timeout)
    within('#mv-confirm') { click_button('No') }
    wait_for_turbo_idle(timeout: timeout)
  end

  def open_preferences
    expect(page).to have_css('a[data-testid="preferences_link"]')
    find('a[data-testid="preferences_link"]').click
    wait_for_turbo_idle
    expect(page).to have_css('div.mv-drawer-root.is-open')
  end
end

RSpec.configure do |config|
  config.include TurboHelpers, type: :feature
end
