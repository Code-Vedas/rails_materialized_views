# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

require 'rails_helper'

RSpec.describe MatViews::Admin::MatViewRunsController, type: :controller do
  routes { MatViews::Engine.routes }

  let(:lang)      { I18n.locale.to_s }
  let(:frame_id)  { 'dash-runs' }

  describe 'GET #index' do
    before do
      allow(controller).to receive(:authorize_mat_views!).and_return(true)
      allow(controller).to receive(:render)
      get :index, params: { lang:, frame_id: }
    end

    it 'authorizes access with correct arguments' do
      expect(controller).to have_received(:authorize_mat_views!).with(:read, :mat_views_runs)
    end

    it 'loads runs' do
      expect(controller.instance_variable_get(:@data)).to eq([])
    end

    it 'responds successfully' do
      expect(response).to be_successful
    end

    context 'when stream=true is provided' do
      before do
        allow(controller).to receive(:render)
        get :index, params: { lang:, frame_id:, stream: 'true' }
      end

      it 'calls turbo stream with filters' do
        expect(controller).to have_received(:render).with(
          hash_including(
            turbo_stream: satisfy do |streams|
              streams.any? do |s|
                s.include?('<turbo-stream action="replace" target="datatable-body-mv-runs-table"')
              end && streams.any? do |s|
                s.include?('<turbo-stream action="replace" target="datatable-tfoot-mv-runs-table"')
              end && streams.any? do |s|
                s.include?('<turbo-stream action="replace" target="datatable-filters-mv-runs-table"')
              end
            end
          )
        )
      end
    end

    context 'when stream=true and index_dt_conifg[:filter_enabled] = false' do
      before do
        allow(controller).to receive(:render)
        original_index_dt_config = controller.send(:index_dt_config)
        original_index_dt_config[:filter_enabled] = false
        allow(controller).to receive(:index_dt_config).and_return(original_index_dt_config)
        get :index, params: { lang:, frame_id:, stream: 'true' }
      end

      it 'calls turbo stream wihout filters' do
        expect(controller).to have_received(:render).with(
          hash_including(
            turbo_stream: satisfy do |streams|
              streams.any? do |s|
                s.include?('<turbo-stream action="replace" target="datatable-body-mv-runs-table"')
              end && streams.any? do |s|
                s.include?('<turbo-stream action="replace" target="datatable-tfoot-mv-runs-table"')
              end && streams.none? do |s|
                s.include?('<turbo-stream action="replace" target="datatable-filters-mv-runs-table"')
              end
            end
          )
        )
      end
    end
  end

  describe 'GET #show' do
    let(:run_id) { '7' }
    let(:run_obj) { Struct.new(:id).new(run_id.to_i) }

    before do
      allow(controller).to receive(:authorize_mat_views!).and_return(true)
      allow(MatViews::MatViewRun).to receive(:find).with(run_id).and_return(run_obj)
      allow(controller).to receive(:render)

      get :show, params: { lang:, frame_id:, id: run_id }
    end

    it 'finds the run and authorizes it' do
      expect(MatViews::MatViewRun).to have_received(:find).with(run_id)
      expect(controller).to have_received(:authorize_mat_views!).with(:read, :mat_views_run, run_obj)
    end

    it 'assigns @run' do
      expect(controller.instance_variable_get(:@run)).to eq(run_obj)
    end

    it 'responds successfully' do
      expect(response).to be_successful
    end
  end
end
