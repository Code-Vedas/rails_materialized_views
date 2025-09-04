# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

require 'rails_helper'

RSpec.describe MatViews::Admin::RunsController, type: :controller do
  routes { MatViews::Engine.routes }

  let(:fake_relation_klass) do
    Class.new do
      attr_reader :calls

      def initialize = @calls = []

      def where(hash)
        @calls << [:where, hash]
        self
      end
    end
  end

  let(:lang)      { I18n.locale.to_s }
  let(:frame_id)  { 'dash-runs' }
  let(:frame_action) { 'filter' }

  describe 'GET #index' do
    let(:fake_relation) { fake_relation_klass.new }
    let(:defs_array) do
      [Struct.new(:id, :name).new(1, 'A'), Struct.new(:id, :name).new(2, 'B')]
    end

    before do
      allow(controller).to receive(:authorize_mat_views!).and_return(true)
      allow(MatViews::MatViewDefinition).to receive(:order).with(:name).and_return(defs_array)
      allow(MatViews::MatViewRun).to receive(:order).with(started_at: :desc).and_return(fake_relation)
      allow(controller).to receive(:render)
    end

    context 'without filters' do
      before do
        get :index, params: { lang:, frame_id:, frame_action: }
      end

      it 'authorizes access with correct arguments' do
        expect(controller).to have_received(:authorize_mat_views!).with(:read, :mat_views_runs)
      end

      it 'loads definitions ordered by name' do
        expect(MatViews::MatViewDefinition).to have_received(:order).with(:name)
        expect(controller.instance_variable_get(:@definitions)).to eq(defs_array)
      end

      it 'loads runs ordered by started_at desc without applying where filters' do
        expect(MatViews::MatViewRun).to have_received(:order).with(started_at: :desc)
        expect(fake_relation.calls).to be_empty
        expect(controller.instance_variable_get(:@runs)).to eq(fake_relation)
      end

      it 'responds successfully' do
        expect(response).to be_successful
      end
    end

    context 'with filters (mat_view_definition_id, operation, status)' do
      let(:params_hash) do
        {
          lang:, frame_id:, frame_action:,
          mat_view_definition_id: '42',
          operation: 'refresh',
          status: 'success'
        }
      end

      before { get :index, params: params_hash }

      it 'applies where clauses for each present filter' do
        expect(fake_relation.calls).to include([:where, { mat_view_definition_id: '42' }])
        expect(fake_relation.calls).to include([:where, { operation: 'refresh' }])
        expect(fake_relation.calls).to include([:where, { status: 'success' }])
      end

      it 'still assigns @runs to the (filtered) relation' do
        expect(controller.instance_variable_get(:@runs)).to eq(fake_relation)
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
      expect(controller).to have_received(:authorize_mat_views!).with(:read, run_obj)
    end

    it 'assigns @run' do
      expect(controller.instance_variable_get(:@run)).to eq(run_obj)
    end

    it 'responds successfully' do
      expect(response).to be_successful
    end
  end
end
