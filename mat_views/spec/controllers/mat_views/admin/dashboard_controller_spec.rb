# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

RSpec.describe MatViews::Admin::DashboardController, type: :controller do
  routes { MatViews::Engine.routes }

  describe 'GET #index' do
    before do
      allow(controller).to receive(:authorize_mat_views!).and_return(true)
      get :index, params: { lang: I18n.locale.to_s }
    end

    it 'authorizes access with the correct arguments' do
      expect(controller).to have_received(:authorize_mat_views!).with(:view, :mat_views_dashboard)
    end

    it 'sets the metrics placeholder note' do
      expect(controller.instance_variable_get(:@metrics_note))
        .to eq('Metrics coming soon (see: Aggregate refresh metrics for reporting).')
    end

    it 'responds successfully' do
      expect(response).to be_successful
    end

    it 'exposes #user as an alias of #mat_views_current_user' do
      expect(controller.user.email).to eq(controller.mat_views_current_user.email)
    end
  end
end
