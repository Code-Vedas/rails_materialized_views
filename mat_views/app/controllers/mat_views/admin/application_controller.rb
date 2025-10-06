# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

module MatViews
  module Admin
    # MatViews::Admin::ApplicationController
    # --------------------------------------
    # Base controller for the MatViews admin interface.
    #
    # Responsibilities:
    # - Provides authentication and authorization via MatViews::Admin::AuthBridge.
    # - Applies the `mat_views/admin` layout and includes UI helpers.
    # - Manages locale (`I18n.locale`) and enforces language parameter consistency.
    # - Sets the browser time zone around each request when provided via cookies.
    # - Exposes `mat_views_data_theme` (light/dark) for theming via cookies.
    # - Provides frame helpers (`render_frame`, `ensure_frame`) to support Turbo-driven
    #   admin UI navigation.
    #
    # Filters:
    # - `before_action`: sets locale and redirects to enforce `lang` consistency.
    # - `around_action`: wraps requests in the browser’s time zone if valid.
    #
    # Methods:
    # - {#default_url_options} ensures `lang` param is included in generated URLs.
    # - {#set_time_zone} runs the request in the cookie-provided time zone if valid.
    # - {#render_frame} renders a UI frame partial given `frame_id`.
    # - {#ensure_frame} requires a `frame_id` param for frame-only actions.
    # - {#redirect_to_lang} redirects when the URL `lang` param differs from `I18n.locale`.
    # - {#set_mat_views_locale} sets the session-defined or default locale.
    # - {#mat_views_data_theme} returns `light`, `dark`, or `nil` for theming.
    #
    class ApplicationController < ActionController::Base
      include MatViews::Admin::AuthBridge

      helper MatViews::Admin::UiHelper
      helper MatViews::Admin::LocalizedDigitHelper
      helper MatViews::Admin::DatatableHelper
      helper MatViews::Helpers::UiTestIds
      layout 'mat_views/admin'

      before_action :set_mat_views_locale, :redirect_to_lang
      helper_method :mat_views_data_theme
      around_action :set_time_zone

      private

      # Default URL options, ensuring `lang` is always included.
      #
      # @api private
      #
      # @return [Hash{Symbol => String}]
      def default_url_options
        { lang: params[:lang].presence || I18n.locale }
      end

      # Wraps the request in the browser’s time zone if one is set in cookies.
      #
      # @api private
      #
      # @yield the block representing the request lifecycle
      # @return [void]
      def set_time_zone(&)
        browser_tz = cookies[:browser_tz]
        if browser_tz.present? && ActiveSupport::TimeZone[browser_tz]
          Time.use_zone(browser_tz, &)
        else
          yield
        end
      end

      # Ensures a `frame_id` param is present.
      # If missing, redirects to the admin root with an alert.
      #
      # @api private
      #
      # @return [void]
      def ensure_frame
        @frame_id = params[:frame_id]
        return if @frame_id.present?

        redirect_to admin_root_path, alert: I18n.t('mat_views.errors.frame_only')
      end

      # Redirects to enforce that the `lang` param matches `I18n.locale`.
      #
      # @api private
      #
      # @return [void]
      def redirect_to_lang
        locale_str = locale.to_s
        return if params[:lang] == locale_str

        lang = locale_str
        redirect_to url_for(params.permit!.to_h.merge(lang: lang)), status: :see_other
      end

      # Sets the locale for MatViews admin requests.
      # Falls back to default locale if session value is invalid.
      #
      # @api private
      #
      # @return [void]
      def set_mat_views_locale
        I18n.locale = if (loc = session[:mat_views_locale]).present? && MatViews::Engine.available_locales.map(&:to_s).include?(loc)
                        loc
                      else
                        MatViews::Engine.default_locale
                      end
      end

      # Returns the current theme for the admin UI.
      #
      # @api private
      #
      # @return ["light", "dark", nil] the theme stored in cookies, or `nil` if invalid
      def mat_views_data_theme
        theme = cookies[:theme].to_s
        %w[light dark].include?(theme) ? theme : nil
      end

      # Returns the current locale.
      #
      # @api private
      #
      # @return [Symbol] the current I18n locale
      def locale
        I18n.locale
      end
    end
  end
end
