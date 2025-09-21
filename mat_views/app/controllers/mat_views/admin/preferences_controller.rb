# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

module MatViews
  module Admin
    # MatViews::Admin::PreferencesController
    # --------------------------------------
    # Controller for managing user preferences in the MatViews admin UI.
    #
    # Responsibilities:
    # - Allows users to view and update UI preferences such as theme and locale.
    # - Stores theme in cookies and locale in session.
    # - Provides a force-reload response option to update Turbo frames dynamically.
    #
    # Filters:
    # - `before_action :authorize!` → ensures user can access preferences.
    # - `before_action :ensure_frame` → requires Turbo frame context for `show`.
    #
    class PreferencesController < ApplicationController
      before_action :authorize!
      before_action :ensure_frame

      # GET /:lang/admin/preferences
      #
      # Displays the current preferences (theme + locale) and available locales.
      # If `force_reload=1` is passed, sets a non-standard status code (299) and
      # a custom header to signal the client to reload.
      #
      # @return [void]
      def show
        @theme   = read_theme
        @locale  = I18n.locale.to_s
        @locales = MatViews::Engine.locale_code_mapping.sort_by { |_key, name| name }.map { |code, _name| code.to_s }.uniq

        # force reload frame if requested
        if params[:force_reload].to_s == '1'
          response.status = 299
          response.set_header('X-Status-Name', 'Success force reload')
        end

        render 'show', formats: :html, layout: 'mat_views/turbo_frame'
      end

      # PATCH/PUT /:lang/admin/preferences
      #
      # Updates preferences:
      # - Theme (`light`, `dark`, or deleted if invalid) stored in cookies.
      # - Locale stored in session if valid.
      # Redirects back to preferences with `force_reload=1` to trigger a refresh.
      #
      # @return [void]
      def update
        theme_param = params[:theme].to_s
        case theme_param
        when 'light', 'dark' then cookies[:theme] = { value: theme_param, expires: 1.year.from_now, httponly: false }
        else cookies.delete(:theme)
        end

        locale = params[:locale].to_s.presence || MatViews::Engine.default_locale.to_s
        session[:mat_views_locale] = locale if MatViews::Engine.available_locales.map(&:to_s).include?(locale)

        redirect_to "#{admin_preferences_path}?force_reload=1&frame_id=#{@frame_id}", status: :see_other
      end

      private

      # Authorizes access to preferences.
      #
      # @api private
      #
      # @return [void]
      def authorize!
        authorize_mat_views!(:read, MatViews::MatViewDefinition)
      end

      # Reads the theme from cookies.
      #
      # @api private
      #
      # @return ["light", "dark", "auto"] theme preference or "auto" if unset/invalid
      def read_theme
        t = cookies[:theme].to_s
        %w[light dark].include?(t) ? t : 'auto'
      end
    end
  end
end
