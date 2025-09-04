# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

require 'nokogiri'

RSpec.describe MatViews::Admin::UiHelper, type: :helper do
  # Helper to parse a single element out of an HTML fragment
  def first(css, html)
    Nokogiri::HTML.fragment(html).at_css(css)
  end

  describe '#mv_button_classes' do
    it 'builds the expected class string' do
      expect(helper.mv_button_classes(:secondary, :lg))
        .to eq('mv-btn mv-btn--secondary mv-btn--lg')
    end
  end

  describe '#mv_button_link' do
    it 'renders a link with classes, tooltip data and confirm' do
      html = helper.mv_button_link('/path',
                                   variant: :secondary,
                                   size: :lg,
                                   underline: true,
                                   tooltip: 'Tip',
                                   tooltip_placement: 'bottom',
                                   confirm: 'Are you sure?',
                                   data: { foo: 'bar' }) { 'Go' }

      a = first('a', html)
      expect(a.text).to eq('Go')
      expect(a['href']).to eq('/path')
      expect(a['class']).to include('mv-btn mv-btn--secondary mv-btn--lg')
      expect(a['class']).to include('underline')
      expect(a['data-foo']).to eq('bar')
      expect(a['data-tooltip-text-value']).to eq('Tip')
      expect(a['data-tooltip-placement']).to eq('bottom')
      expect(a['data-turbo-confirm']).to eq('Are you sure?')
    end
  end

  describe '#mv_drawer_link' do
    it 'renders a drawer-triggering link with proper data attributes' do
      html = helper.mv_drawer_link('/drawer/url', 'My Drawer', variant: :ghost) { 'Open' }
      a = first('a', html)
      expect(a.text).to eq('Open')
      expect(a['href']).to eq('#')
      expect(a['data-action']).to eq('click->drawer#open')
      expect(a['data-drawer-title']).to eq('My Drawer')
      expect(a['data-drawer-url']).to eq('/drawer/url')
      expect(a['class']).to include('mv-btn mv-btn--ghost')
    end
  end

  describe '#mv_button_to' do
    it 'renders a form/button with classes and content' do
      html = helper.mv_button_to('/submit', variant: :primary, size: :sm) { 'Create' }
      form = first('form', html)
      button = first('form button', html)

      expect(form['action']).to eq('/submit')
      expect(form['method']).to eq('get')
      expect(button['class']).to include('mv-btn mv-btn--primary mv-btn--sm')
      expect(button.text).to eq('Create')
    end
  end

  describe '#mv_drawer_action_button' do
    it 'renders a button with drawer action and optional tooltip' do
      html = helper.mv_drawer_action_button('Refresh', 'reload', 'Reload now', 'top') { 'R' }
      btn = first('button', html)

      expect(btn['class']).to include('mv-drawer-action')
      expect(btn['aria-label']).to eq('Refresh')
      expect(btn['data-action']).to eq('drawer#reload')
      expect(btn['data-controller']).to eq('tooltip')
      expect(btn['data-tooltip-text-value']).to eq('Reload now')
      expect(btn['data-tooltip-placement']).to eq('top')
      expect(btn.text).to eq('R')
    end

    it 'omits tooltip data when not provided' do
      html = helper.mv_drawer_action_button('Refresh', 'reload') { 'R' }
      btn = first('button', html)

      expect(btn['data-controller']).to be_nil
      expect(btn['data-tooltip-text-value']).to be_nil
      expect(btn['data-tooltip-placement']).to be_nil
    end
  end

  describe '#mv_link_to' do
    it 'renders a non-block link, defaulting target to _blank and supporting tooltip' do
      html = helper.mv_link_to('Docs', 'https://example.com', tooltip: 'Open docs')
      a = first('a', html)

      expect(a.text).to eq('Docs')
      expect(a['href']).to eq('https://example.com')
      expect(a['target']).to eq('_blank')
      expect(a['rel']).to eq('noopener noreferrer')
      expect(a['class']).to include('underline')
      expect(a['data-controller']).to eq('tooltip')
      expect(a['data-tooltip-text-value']).to eq('Open docs')
    end

    it 'renders a block link with content' do
      html = helper.mv_link_to('/x', {}) { '<strong>Bold</strong>'.html_safe }
      a = first('a', html)
      expect(a['href']).to eq('/x')
      expect(a.inner_html).to include('<strong>Bold</strong>')
    end

    it 'renders a non-block link without _blank when is_blank: false' do
      html = helper.mv_link_to('Internal', '/internal', is_blank: false)
      a = first('a', html)

      expect(a.text).to eq('Internal')
      expect(a['href']).to eq('/internal')
      expect(a['target']).to be_nil
      expect(a['rel']).to be_nil
      expect(a['class']).to include('underline')
      expect(a['data-controller']).to be_nil
    end

    it 'renders a non-block link without underline when underline: false' do
      html = helper.mv_link_to('No Underline', '/no-underline', underline: false)
      a = first('a', html)

      expect(a.text).to eq('No Underline')
      expect(a['href']).to eq('/no-underline')
      expect(a['class']).to be_nil
    end
  end

  describe '#mv_tab_link' do
    it 'renders a tab link with active class when selected' do
      html = helper.mv_tab_link('runs', selected: true) do
        'Tab 1'
      end
      a = first('a', html)

      expect(a.text).to eq('Tab 1')
      expect(a['href']).to eq('#')
      expect(a['data-action']).to eq('click->tabs#show')
      expect(a['data-tabs-target']).to eq('link')
      expect(a['data-name']).to eq('runs')
      expect(a['class']).to include('mv-tab mv-tab--on')
    end

    it 'renders a tab link without active class when not selected' do
      html = helper.mv_tab_link('definitions', selected: false) do
        'Tab 2'
      end
      a = first('a', html)

      expect(a.text).to eq('Tab 2')
      expect(a['href']).to eq('#')
      expect(a['data-action']).to eq('click->tabs#show')
      expect(a['data-tabs-target']).to eq('link')
      expect(a['data-name']).to eq('definitions')
      expect(a['class']).to eq('mv-tab')
    end
  end

  describe '#mv_t' do
    around do |ex|
      old_backend = I18n.backend
      I18n.backend = I18n::Backend::Simple.new
      I18n.backend.store_translations(:en, { mat_views: { greet: 'Howdy %<name>s' } })
      I18n.locale = :en
      ex.run
    ensure
      I18n.backend = old_backend
    end

    it 'translates under mat_views.*' do
      expect(helper.mv_t('greet', name: 'Ada')).to eq('Howdy Ada')
    end
  end

  describe '#mv_badge' do
    it 'renders a success badge' do
      html = helper.mv_badge(:success)
      span = first('span', html)
      expect(span['class']).to include('mv-badge mv-badge--success')
      expect(span.text).to eq('success')
    end

    it 'renders a failed badge' do
      html = helper.mv_badge(:failed)
      span = first('span', html)
      expect(span['class']).to include('mv-badge mv-badge--failed')
      expect(span.text).to eq('failed')
    end

    it 'renders a running badge' do
      html = helper.mv_badge(:running)
      span = first('span', html)
      expect(span['class']).to include('mv-badge mv-badge--running')
      expect(span.text).to eq('running')
    end

    it 'renders a default badge for unknown status' do
      html = helper.mv_badge(:custom)
      span = first('span', html)
      expect(span['class']).to eq('mv-badge')
      expect(span.text).to eq('custom')
    end
  end

  describe '#mv_icon' do
    it 'renders an SVG wrapper with the requested icon body' do
      html = helper.mv_icon(:refresh, size: 24, class_name: 'extra')
      svg = first('svg', html)

      expect(svg['class']).to include('mv-icon')
      expect(svg['class']).to include('extra')
      expect(svg['width']).to eq('24')
      expect(svg['height']).to eq('24')
      expect(svg['viewbox']).to eq('0 0 24 24')
      # ensure some inner path content rendered
      expect(svg.inner_html.strip).not_to be_empty
    end

    it 'renders an empty-body SVG when icon name is unknown' do
      html = helper.mv_icon(:does_not_exist)
      svg = first('svg', html)
      expect(svg.inner_html.strip).to eq('')
    end
  end

  describe '#mv_submit_button' do
    it 'renders a submit button with classes and content' do
      html = helper.mv_submit_button(variant: :primary, size: :md) { 'Submit' }
      button = first('button', html)

      expect(button['type']).to eq('submit')
      expect(button['class']).to include('mv-btn mv-btn--primary mv-btn--md')
      expect(button.text).to eq('Submit')
    end
  end

  describe '#mv_cancel_button' do
    it 'renders a cancel button with classes and content' do
      html = helper.mv_cancel_button(variant: :ghost, size: :sm) { 'Cancel' }
      button = first('button', html)

      expect(button['type']).to eq('button')
      expect(button['class']).to include('mv-btn mv-btn--ghost mv-btn--sm')
      expect(button.text).to eq('Cancel')
    end
  end

  describe 'svg icon methods' do
    let(:icon_names) do
      %i[svg_icon_arrow_right svg_icon_refresh svg_icon_trash svg_icon_hammer svg_icon_x_circle svg_icon_plus_circle svg_icon_check_circle svg_icon_alert
         svg_icon_history svg_icon_edit svg_icon_layers svg_icon_database svg_icon_gear]
    end

    it 'all responds and return string' do
      icon_names.each do |icon_name|
        expect(helper.respond_to?(icon_name, true)).to be true
        result = helper.send(icon_name)
        expect(result).to be_a(String)
        expect(result).to start_with('<')
        expect(result).to end_with('>')
      end
    end
  end

  describe '#assign_test_id' do
    it 'assigns data-test-id attribute when provided' do
      html = helper.mv_button_link('/path', testid: 'EDIT_LINK') { 'Click' }
      a = first('a', html)
      expect(a['data-testid']).to eq('edit_link')
    end

    it 'assigns data-testid with identifier if provided' do
      html = helper.mv_button_link('/path', testid: 'EDIT_LINK', testid_identifier: '42') { 'Click' }
      a = first('a', html)
      expect(a['data-testid']).to eq('edit_link-42')
    end

    it 'does not assign data-testid attribute when not provided' do
      html = helper.mv_button_link('/path') { 'Click' }
      a = first('a', html)
      expect(a['data-testid']).to be_nil
    end
  end
end
