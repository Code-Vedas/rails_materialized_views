# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

RSpec.describe Smriti::Admin::PreferencesController, type: :controller do
  routes { Smriti::Engine.routes }

  let(:lang)         { I18n.locale.to_s }
  let(:frame_id)     { 'dash-preferences' }

  before do
    allow(controller).to receive(:authorize_smriti!).and_return(true)
  end

  describe 'GET #show' do
    before { allow(controller).to receive(:render) }

    context 'without force_reload' do
      before do
        cookies[:theme] = 'dark'
        get :show, params: { lang:, frame_id: }
      end

      it 'authorizes access to preferences' do
        expect(controller).to have_received(:authorize_smriti!).with(:view, :smriti_dashboard)
      end

      it 'assigns theme, locale, and locales list' do
        expect(controller.instance_variable_get(:@theme)).to eq('dark')
        expect(controller.instance_variable_get(:@locale)).to eq(lang)
        expected_values = Smriti::Engine.locale_code_mapping.sort_by { |_, name| name }.map { |code, _name| code.to_s }.uniq
        expect(controller.instance_variable_get(:@locales)).to eq(expected_values)
      end

      it 'responds successfully and does not set force-reload status/header' do
        expect(response).to be_successful
        expect(response).not_to have_http_status(299)
        expect(response.get_header('X-Status-Name')).to be_nil
      end
    end

    context 'with force_reload=1' do
      before do
        get :show, params: { lang:, frame_id:, force_reload: '1' }
      end

      it 'sets non-standard 299 status and X-Status-Name header' do
        expect(response).to have_http_status(299)
        expect(response.get_header('X-Status-Name')).to eq('Success force reload')
      end
    end
  end

  describe 'PATCH #update' do
    context 'with valid theme and valid locale' do
      before do
        patch :update, params: { lang:, frame_id:, theme: 'light', locale: 'en' }
      end

      it 'authorizes access' do
        expect(controller).to have_received(:authorize_smriti!).with(:view, :smriti_dashboard)
      end

      it 'sets the theme cookie' do
        expect(cookies[:theme]).to eq('light')
      end

      it 'stores the locale in session when allowed' do
        expect(session[:smriti_locale]).to eq('en')
      end

      it 'redirects back with force_reload=1 and carries frame_id' do
        expect(response).to have_http_status(:see_other)
        expected_url = 'http://test.host/smriti/en/admin/preferences?force_reload=1&frame_id=dash-preferences'
        expect(response).to redirect_to(expected_url)
      end
    end

    context 'with invalid theme and invalid locale' do
      before do
        session.delete(:smriti_locale)
        cookies.delete(:theme)

        patch :update, params: { lang:, frame_id:, theme: 'solarized', locale: 'frr' }
      end

      it 'deletes the theme cookie' do
        expect(cookies[:theme]).to be_nil
      end

      it 'does not set session locale when not allowed' do
        expect(session[:smriti_locale]).to be_nil
      end

      it 'redirects with force_reload=1 and frame_id' do
        expect(response).to have_http_status(:see_other)
        expected_url = 'http://test.host/smriti/en/admin/preferences?force_reload=1&frame_id=dash-preferences'
        expect(response.location).to eq(expected_url)
      end
    end
  end
end
