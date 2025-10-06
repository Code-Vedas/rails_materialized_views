# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

LANG_RE = /[a-z]{2,8}(?:-[A-Za-z0-9]{2,12})?(?:-[A-Za-z0-9]{2,8})?/i
MatViews::Engine.routes.draw do
  scope '(:lang)', constraints: { lang: LANG_RE } do
    namespace :admin do
      root to: 'dashboard#index'
      resource :preferences, only: %i[show update]
      resources :mat_view_definitions, path: 'definitions' do
        member do
          post :create_now
          post :refresh
          post :delete_now
        end
      end
      resources :mat_view_runs, only: %i[index show], path: 'runs'

      # redirect to dashboard for unknown paths.
      get '*path', to: redirect { |params, req|
        lang = (params[:lang].presence || MatViews::Engine.default_locale).to_s
        "#{req.script_name}/#{lang}/admin"
      }
    end

    # redirect to admin dashboard for root path including lang.
    root to: redirect { |params, req|
      lang = (params[:lang].presence || MatViews::Engine.default_locale).to_s
      "#{req.script_name}/#{lang}/admin"
    }
  end
end
