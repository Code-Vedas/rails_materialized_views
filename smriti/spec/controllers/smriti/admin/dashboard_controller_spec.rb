# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

RSpec.describe Smriti::Admin::DashboardController, type: :controller do
  routes { Smriti::Engine.routes }

  describe 'GET #index' do
    before do
      allow(controller).to receive(:authorize_smriti!).and_return(true)
      get :index, params: { lang: I18n.locale.to_s }
    end

    it 'authorizes access with the correct arguments' do
      expect(controller).to have_received(:authorize_smriti!).with(:view, :smriti_dashboard)
    end

    it 'sets the metrics placeholder note' do
      expect(controller.instance_variable_get(:@metrics_note))
        .to eq('Metrics coming soon (see: Aggregate refresh metrics for reporting).')
    end

    it 'responds successfully' do
      expect(response).to be_successful
    end

    it 'exposes #user as an alias of #smriti_current_user' do
      expect(controller.user.email).to eq(controller.smriti_current_user.email)
    end
  end
end
