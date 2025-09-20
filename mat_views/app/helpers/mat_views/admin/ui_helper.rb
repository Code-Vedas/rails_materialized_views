# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

module MatViews
  module Admin
    # MatViews::Admin::UiHelper
    # -------------------------
    # View helper methods for the MatViews admin UI.
    #
    # Responsibilities:
    # - Provides consistent button, link, drawer, badge, and icon components.
    # - Wraps standard Rails helpers (`link_to`, `button_to`, `button_tag`, etc.)
    #   with MatViews-specific styling and Stimulus integration.
    # - Defines inline SVG icon snippets for use across the admin dashboard.
    #
    # Key Components:
    # - Buttons: {#mv_button_link}, {#mv_button_to}, {#mv_drawer_link}, {#mv_drawer_action_button}
    # - Links: {#mv_link_to}
    # - Badges: {#mv_badge}
    # - Icons: {#mv_icon} with private `svg_icon_*` methods
    # - Translations: {#mv_t}
    #
    module UiHelper
      # Builds CSS classes for a MatViews-styled button.
      #
      # @param variant [Symbol] one of `:primary`, `:secondary`, `:ghost`, `:negative`
      # @param size [Symbol] one of `:sm`, `:md`, `:lg`
      # @return [String] concatenated CSS class string
      def mv_button_classes(variant, size)
        [
          'mv-btn',
          "mv-btn--#{variant}",
          "mv-btn--#{size}"
        ].join(' ')
      end

      # Renders a styled link button.
      #
      # @param href [String] target URL
      # @param opts [Hash] options for styling, data attributes, etc.
      # @yield link body content
      # @return [String] HTML-safe link tag
      def mv_button_link(href, opts = {}, &)
        link_to capture(&), href, **link_options(assign_test_id(opts))
      end

      # Renders a button link that opens a drawer via Stimulus.
      #
      # @param drawer_url [String] URL to load into the drawer
      # @param drawer_title [String] title for the drawer
      # @param args [Hash] additional options
      # @yield button body
      # @return [String] HTML-safe link tag
      def mv_drawer_link(drawer_url, drawer_title, args = {}, &)
        data = { action: 'click->drawer#open', drawer_title: drawer_title, drawer_url: drawer_url }
        args[:data] = (args[:data] || {}).merge(data)
        mv_button_link '#', assign_test_id(args), &
      end

      # Renders a styled `button_to` element.
      #
      # @param href [String] target URL
      # @param opts [Hash] options for styling, data attributes, etc.
      # @yield button content
      # @return [String] HTML-safe button tag
      def mv_button_to(href, opts = {}, &)
        button_to href, **link_options(assign_test_id(opts)) do
          capture(&)
        end
      end

      # Renders a drawer action button with optional tooltip.
      #
      # @param label [String] ARIA label for accessibility
      # @param action [String] Stimulus action method
      # @param tooltip [String, nil] optional tooltip text
      # @param tooltip_placement [String, nil] placement of tooltip (default: "top")
      # @param args_orig [Hash] additional HTML options
      # @yield button content
      # @return [String] HTML-safe button tag
      def mv_drawer_action_button(label, action, tooltip = nil, tooltip_placement = nil, args_org = {}, &)
        args = assign_test_id(args_org)
        data = { action: "drawer##{action}" }
        data = data.merge(args[:data] || {})
        if tooltip
          data[:controller] = 'tooltip'
          data[:'tooltip-text-value'] = tooltip
          data[:'tooltip-placement'] = tooltip_placement || 'top'
        end

        args[:data] = data

        button_tag(type: 'button', class: 'mv-drawer-action', 'aria-label': label, **args, &)
      end

      # Renders a styled external or internal link, with optional tooltip.
      #
      # @param text [String, nil] link text (nil if using block form)
      # @param url [String, nil] target URL
      # @param args_orig [Hash] HTML options (supports `:tooltip`, `:is_blank`)
      # @yield link body when block form is used
      # @return [String] HTML-safe link tag
      def mv_link_to(text = nil, url = nil, args_orig = nil, &block)
        args = assign_test_id(args_orig || {})
        if block_given?
          args = assign_test_id(url || {})
          url = text
        end

        tooltip = args.fetch(:tooltip, nil)
        is_blank = args.fetch(:is_blank, true)
        underline = args.fetch(:underline, true)
        args_to_apply = args.except(:tooltip, :is_blank)
        if is_blank
          args_to_apply[:target] = '_blank'
          args_to_apply[:rel] = 'noopener noreferrer'
        end
        args_to_apply[:class] = 'underline' if underline
        if tooltip
          args_to_apply[:'data-controller'] = 'tooltip'
          args_to_apply[:'data-tooltip-text-value'] = tooltip
        end

        if block_given?
          link_to url, args_to_apply do
            capture(&block)
          end
        else
          link_to text, url, **args_to_apply
        end
      end

      # Renders a tab link for the tabs component.
      # @param tab_name [String] unique name of the tab
      # @param args_org [Hash] additional HTML options
      #
      # @yield tab link content
      #
      # @return [String] HTML-safe link tag
      def mv_tab_link(tab_name, args_org = {}, &)
        args = assign_test_id(args_org)
        classes = ['mv-tab']
        selected = args.delete(:selected)
        classes << (selected ? 'mv-tab--on' : '')
        args[:class] = [args[:class], classes.compact.join(' ')].compact.join(' ').strip
        args[:data] = args.fetch(:data, {}).merge({ action: 'click->tabs#show', 'tabs-target': 'link', name: tab_name })
        link_to '#', **args, &
      end

      # Shortcut for translating keys under the `mat_views` namespace.
      #
      # @param key [String, Symbol] translation key under `mat_views.*`
      # @param args [Hash] interpolation values
      # @return [String] translated string
      def mv_t(key, **args)
        I18n.t("mat_views.#{key}", **args)
      end

      # Renders a badge element styled by status.
      #
      # @param status [String, Symbol] status name (`success`, `running`, `failed`, etc.)
      # @param text [String] text to display inside the badge
      # @return [String] HTML-safe span tag with badge classes
      def mv_badge(status, text)
        klass = case status.to_s.downcase
                when 'success' then 'mv-badge mv-badge--success'
                when 'running' then 'mv-badge mv-badge--running'
                when 'failed'  then 'mv-badge mv-badge--failed'
                else 'mv-badge'
                end
        content_tag(:span, text, class: klass)
      end

      # Renders an inline SVG icon.
      #
      # @param name [String, Symbol] icon name (method suffix after `svg_icon_`)
      # @param size [Integer] icon width/height in pixels
      # @param class_name [String, nil] optional extra CSS class
      # @return [String] HTML-safe SVG element
      def mv_icon(name, size: 16, class_name: nil)
        icon_method_name = :"svg_icon_#{name}"
        content_tag :svg,
                    class: ['mv-icon', class_name].compact.join(' '),
                    xmlns: 'http://www.w3.org/2000/svg',
                    width: size, height: size, viewBox: '0 0 24 24',
                    fill: 'none', stroke: 'currentColor',
                    'stroke-width': '2', 'stroke-linecap': 'round', 'stroke-linejoin': 'round',
                    'aria-hidden': 'true' do
          respond_to?(icon_method_name, true) ? raw(send(icon_method_name)) : ''.html_safe
        end
      end

      # Renders a styled submit button.
      #
      # @param opts [Hash] options for styling, data attributes, etc.
      #
      # @yield button content
      #
      # @return [String] HTML-safe button tag
      def mv_submit_button(opts = {}, &)
        opts = link_options(assign_test_id(opts))
        opts[:type] = 'submit'
        opts.delete(:method)
        button_tag(capture(&), **opts)
      end

      # Renders a styled cancel button.
      # @param opts [Hash] options for styling, data attributes, etc.
      #
      # @yield button content
      #
      # @return [String] HTML-safe button tag
      def mv_cancel_button(opts = {}, &)
        opts = link_options(assign_test_id(opts))
        opts[:type] = 'button'
        opts.delete(:method)
        button_tag(capture(&), **opts)
      end

      private

      # Builds standardized options hash for button/link helpers.
      #
      # @param opts [Hash] options including :variant, :size, :method, :tooltip, etc.
      # @return [Hash] merged HTML attributes (class, method, data)
      def link_options(opts)
        variant = opts.fetch(:variant, :primary)
        size = opts.fetch(:size, :md)
        method = opts.fetch(:method, :get)
        underline = opts[:underline] ? ' underline' : ''

        tip      = opts[:tooltip]
        tooltip  = if tip
                     {
                       controller: 'tooltip',
                       'tooltip-text-value': tip,
                       'tooltip-placement': opts.fetch(:tooltip_placement, 'top')
                     }
                   else
                     {}
                   end

        html_data = (opts[:data] || {}).dup.merge(tooltip)
        html_data[:'turbo-confirm'] = opts.fetch(:confirm, nil)
        { class: "#{mv_button_classes(variant, size)}#{underline}", method: method, data: html_data }
      end

      # @return [String] SVG markup for a right-pointing arrow icon
      def svg_icon_arrow_right
        <<~SVG.strip.freeze
          <polyline points="9 18 15 12 9 6"/>
        SVG
      end

      # @return [String] SVG markup for a refresh/reload icon
      def svg_icon_refresh
        <<~SVG.strip.freeze
          <path d="M21 12a9 9 0 1 1-2.64-6.36"/>
          <polyline points="23 4 23 10 17 10"/>
        SVG
      end

      # @return [String] SVG markup for a trash/delete (bin) icon
      def svg_icon_trash
        <<~SVG.strip.freeze
          <polyline points="3 6 5 6 21 6"/>
          <path d="M19 6l-1 14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2L5 6"/>
          <path d="M10 11v6"/>
          <path d="M14 11v6"/>
          <path d="M9 6V4a2 2 0 0 1 2-2h2a2 2 0 0 1 2 2v2"/>
        SVG
      end

      # @return [String] SVG markup for a hammer/tool icon
      def svg_icon_hammer
        <<~SVG.strip.freeze
          <path d="M14 4l7 7"/>
          <path d="M5 15l7-7 3 3-7 7H5v-3z"/>
        SVG
      end

      # @return [String] SVG markup for an “X in a circle” (close/error) icon
      def svg_icon_x_circle
        <<~SVG.strip.freeze
          <circle cx="12" cy="12" r="10"/>
          <path d="M15 9l-6 6"/>
          <path d="M9 9l6 6"/>
        SVG
      end

      # @return [String] SVG markup for a “plus in a circle” (add) icon
      def svg_icon_plus_circle
        <<~SVG.strip.freeze
          <circle cx="12" cy="12" r="10"/>
          <line x1="12" y1="8" x2="12" y2="16"/>
          <line x1="8" y1="12" x2="16" y2="12"/>
        SVG
      end

      # @return [String] SVG markup for a checkmark-in-circle (success) icon
      def svg_icon_check_circle
        <<~SVG.strip.freeze
          <circle cx="12" cy="12" r="10"/>
          <polyline points="9 12 12 15 16 9"/>
        SVG
      end

      # @return [String] SVG markup for an alert/warning triangle icon
      def svg_icon_alert
        <<~SVG.strip.freeze
          <path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"/>
          <line x1="12" y1="9" x2="12" y2="13"/>
          <line x1="12" y1="17" x2="12.01" y2="17"/>
        SVG
      end

      # @return [String] SVG markup for a history/clock icon
      def svg_icon_history
        <<~SVG.strip.freeze
          <path d="M3 3v5h5"/>
          <path d="M3.05 13a9 9 0 1 0 .5-5.5"/>
          <path d="M12 7v5l3 3"/>
        SVG
      end

      # @return [String] SVG markup for an edit/pencil icon
      def svg_icon_edit
        <<~SVG.strip.freeze
          <path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/>
          <path d="M18.5 2.5a2.1 2.1 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"/>
        SVG
      end

      # @return [String] SVG markup for a stacked-layers icon
      def svg_icon_layers
        <<~SVG.strip.freeze
          <polygon points="12 2 2 7 12 12 22 7 12 2"/>
          <polyline points="2 17 12 22 22 17"/>
          <polyline points="2 12 12 17 22 12"/>
        SVG
      end

      # @return [String] SVG markup for a database/cylinder icon
      def svg_icon_database
        <<~SVG.strip.freeze
          <ellipse cx="12" cy="5" rx="9" ry="3"/>
          <path d="M3 5v6c0 1.66 4.03 3 9 3s9-1.34 9-3V5"/>
          <path d="M3 11v6c0 1.66 4.03 3 9 3s9-1.34 9-3v-6"/>
        SVG
      end

      # @return [String] SVG markup for a gear/settings icon
      def svg_icon_gear
        <<~SVG.strip.freeze
          <circle cx="12" cy="12" r="3"></circle>
          <path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-2 2 2 2 0 0 1-2-2v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83 0 2 2 0 0 1 0-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1-2-2 2 2 0 0 1 2-2h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 0-2.83 2 2 0 0 1 2.83 0l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 2-2 2 2 0 0 1 2 2v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 0 2 2 0 0 1 0 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 2 2 2 2 0 0 1-2 2h-.09a1.65 1.65 0 0 0-1.51 1z"></path>
        SVG
      end

      # Maps a symbolic test ID to its actual string value for data attributes.
      # if `:testid` key is not present, returns original args unchanged.
      #
      # @param args [Hash] original options hash
      # @return [Hash] modified options hash with `data-testid` set
      #
      # @example
      #   assign_test_id(class: 'btn', testid: :HEADER_LINK)
      #   # => { class: 'btn', data: { testid: 'header_link' } }
      #
      def assign_test_id(args = {})
        return args unless args[:testid].present?

        testid_constant = args.delete(:testid)
        testid_identifier = args.delete(:testid_identifier) || ''
        args_data = args[:data] || {}
        args_data[:testid] = "#{MatViews::Helpers::UiTestIds.const_get(testid_constant)}-#{testid_identifier}".chomp('-')
        args.merge data: args_data
      end
    end
  end
end
