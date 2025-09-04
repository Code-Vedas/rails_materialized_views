# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

RSpec.describe MatViews::Admin::MatViewDefinitionsController, type: :controller do
  routes { MatViews::Engine.routes }

  let(:lang)         { I18n.locale.to_s }
  let(:frame_id)     { 'some-frame' }
  let(:frame_action) { 'show' }

  let(:config_double) do
    instance_double(MatViews::Configuration,
                    job_queue: 'default',
                    admin_ui: { row_count_strategy: :none })
  end

  before do
    allow(MatViews).to receive(:configuration).and_return(config_double)
    allow(controller).to receive(:authorize_mat_views!).and_return(true)
  end

  describe 'GET #index' do
    let(:defn_one) { create(:mat_view_definition, name: 'A') }
    let(:defn_two) { create(:mat_view_definition, name: 'B') }
    let(:definitions) { [defn_one, defn_two] }
    let(:service_response_one) { instance_double(MatViews::ServiceResponse, response: { exists: true }) }
    let(:service_response_two) { instance_double(MatViews::ServiceResponse, response: { exists: false }) }
    let(:checker_one) { instance_double(MatViews::Services::CheckMatviewExists, call: service_response_one) }
    let(:checker_two) { instance_double(MatViews::Services::CheckMatviewExists, call: service_response_two) }

    before do
      allow(MatViews::MatViewDefinition).to receive(:order).with(:name).and_return(definitions)
      allow(MatViews::Services::CheckMatviewExists).to receive(:new).with(defn_one).and_return(checker_one)
      allow(MatViews::Services::CheckMatviewExists).to receive(:new).with(defn_two).and_return(checker_two)
      allow(controller).to receive(:render)
      get :index, params: { lang:, frame_id:, frame_action: }
    end

    it 'authorizes and assigns @definitions and @mv_exists_map' do
      expect(controller).to have_received(:authorize_mat_views!).with(:read, MatViews::MatViewDefinition)
      expect(controller.instance_variable_get(:@definitions)).to eq(definitions)
      expect(controller.instance_variable_get(:@mv_exists_map)).to eq({ defn_one => true, defn_two => false })
    end

    it 'renders the turbo frame layout' do
      expect(controller).to have_received(:render).with('index', formats: :html, layout: 'mat_views/turbo_frame')
      expect(response).to be_successful
    end
  end

  describe 'GET #show' do
    let(:defn) { create(:mat_view_definition) }
    let(:runs) { create_list(:mat_view_run, 2, mat_view_definition: defn) }
    let(:service_response) { instance_double(MatViews::ServiceResponse, response: { exists: true }) }
    let(:checker) { instance_double(MatViews::Services::CheckMatviewExists, call: service_response) }
    let(:runs_relation) { instance_double(ActiveRecord::Relation, to_a: runs) }
    let(:runs_assoc) { instance_double(ActiveRecord::Relation) }
    let(:ordered_runs) { instance_double(ActiveRecord::Relation, to_a: runs) }

    before do
      allow(MatViews::MatViewDefinition).to receive(:find).with(defn.id.to_s).and_return(defn)
      allow(defn).to receive(:mat_view_runs).and_return(runs_assoc)
      allow(runs_assoc).to receive(:order).with(created_at: :desc).and_return(ordered_runs)
      allow(MatViews::Services::CheckMatviewExists).to receive(:new).with(defn).and_return(checker)
      allow(controller).to receive(:render)
      get :show, params: { lang:, frame_id:, id: defn.id }
    end

    it 'authorizes, assigns @definition, @mv_exists, @runs and renders' do
      expect(controller).to have_received(:authorize_mat_views!).with(:read, defn)
      expect(controller.instance_variable_get(:@mv_exists)).to be(true)
      expect(controller.instance_variable_get(:@runs)).to eq(runs)
      expect(controller).to have_received(:render).with('show', formats: :html, layout: 'mat_views/turbo_frame')
      expect(response).to be_successful
    end
  end

  describe 'GET #new' do
    let(:defn) { create(:mat_view_definition) }

    before do
      allow(MatViews::MatViewDefinition).to receive(:new).and_return(defn)
      allow(controller).to receive(:render) do |*_args|
        controller.head :ok
      end
      get :new, params: { lang:, frame_id:, frame_action: }
    end

    it 'authorizes, builds a new definition and renders' do
      expect(controller).to have_received(:authorize_mat_views!).with(:create, MatViews::MatViewDefinition)
      expect(controller.instance_variable_get(:@definition)).to eq(defn)
      expect(controller).to have_received(:render)
        .with('form', hash_including(formats: :html, layout: 'mat_views/turbo_frame'))

      expect(response).to be_successful
    end
  end

  describe 'GET #edit' do
    let(:defn) { create(:mat_view_definition) }

    before do
      allow(MatViews::MatViewDefinition).to receive(:find).with(defn.id.to_s).and_return(defn)
      allow(controller).to receive(:render) do |*_args|
        controller.head :ok
      end
      get :edit, params: { lang:, frame_id:, id: defn.id }
    end

    it 'authorizes and renders form' do
      expect(controller).to have_received(:authorize_mat_views!).with(:update, defn)
      expect(controller.instance_variable_get(:@definition)).to eq(defn)
      expect(controller).to have_received(:render).with('form', formats: :html, layout: 'mat_views/turbo_frame')
      expect(response).to be_successful
    end
  end

  describe 'POST #create' do
    let(:normalized_params) do
      {
        'name' => 'orders_mv',
        'sql' => 'SELECT 1',
        'refresh_strategy' => 'regular',
        'schedule_cron' => '0 * * * *',
        'unique_index_columns' => 'id, email , ',
        'dependencies' => 'a,b'
      }
    end

    let(:expected_attrs) do
      {
        'name' => 'orders_mv',
        'sql' => 'SELECT 1',
        'refresh_strategy' => 'regular',
        'schedule_cron' => '0 * * * *',
        'unique_index_columns' => %w[id email],
        'dependencies' => %w[a b]
      }
    end

    let(:defn) { create(:mat_view_definition) }

    context 'when save succeeds' do
      before do
        allow(MatViews::MatViewDefinition).to receive(:new)
          .with(hash_including(expected_attrs)).and_return(defn)
        allow(defn).to receive(:save).and_return(true)

        post :create, params: {
          lang:, frame_id:, frame_action:,
          mat_view_definition: normalized_params
        }
      end

      it 'authorizes, normalizes arrays, creates the record and redirects with status 298' do
        expect(controller).to have_received(:authorize_mat_views!).with(:create, MatViews::MatViewDefinition)
        expect(response).to have_http_status(298)
        expect(response.location).to match(%r{/admin/definitions/#{defn.id}\?})
      end
    end

    context 'when save fails' do
      before do
        allow(MatViews::MatViewDefinition).to receive(:new).and_return(defn)
        allow(defn).to receive(:save).and_return(false)
        allow(controller).to receive(:render)

        post :create, params: {
          lang:, frame_id:, frame_action:,
          mat_view_definition: normalized_params
        }
      end

      it 'renders form with unprocessable status' do
        expect(controller).to have_received(:render).with(
          'form', formats: :html, layout: 'mat_views/turbo_frame', status: :unprocessable_content
        )
      end
    end
  end

  describe 'PATCH #update' do
    let(:defn) { create(:mat_view_definition) }

    before do
      allow(MatViews::MatViewDefinition).to receive(:find).and_return(defn)
    end

    context 'when update succeeds' do
      before do
        allow(defn).to receive(:update).and_return(true)
        patch :update, params: {
          lang:, frame_id:, frame_action:, id: defn.id,
          mat_view_definition: {
            name: 'n', sql: 's',
            unique_index_columns: 'id,',
            dependencies: 'x, y'
          }
        }
      end

      it 'redirects with status 298 to the show page' do
        expect(response).to have_http_status(298)
        expect(response.location).to match(%r{/admin/definitions/#{defn.id}\?})
      end
    end

    context 'when update fails' do
      before do
        allow(defn).to receive(:update).and_return(false)
        allow(controller).to receive(:render)
        patch :update, params: {
          lang:, frame_id:, frame_action:, id: defn.id,
          mat_view_definition: { name: '', sql: '' }
        }
      end

      it 'renders the form with 422' do
        expect(controller).to have_received(:render).with(
          'form', formats: :html, layout: 'mat_views/turbo_frame', status: :unprocessable_content
        )
      end
    end
  end

  describe 'DELETE #destroy' do
    let(:defn) { create(:mat_view_definition) }

    before do
      allow(MatViews::MatViewDefinition).to receive(:find).and_return(defn)
      allow(defn).to receive(:destroy!).and_return(true)
    end

    context "when frame_id == 'dash-definitions' redirects to index with 303" do
      before do
        delete :destroy, params: { lang:, frame_id: 'dash-definitions', frame_action:, id: defn.id }
      end

      it 'redirects to definitions index' do
        expect(response).to have_http_status(:see_other)
        expect(response.location).to match(%r{/admin/definitions\?})
      end
    end

    context "when frame_id != 'dash-definitions' renders empty with 298" do
      before do
        allow(controller).to receive(:render)
        delete :destroy, params: { lang:, frame_id:, frame_action:, id: defn.id }
      end

      it 'renders the empty turbo frame with status 298' do
        expect(controller).to have_received(:render).with(
          'empty', formats: :html, layout: 'mat_views/turbo_frame', status: 298
        )
      end
    end
  end

  describe 'POST #create_now' do
    let(:defn) { create(:mat_view_definition) }

    before do
      allow(MatViews::MatViewDefinition).to receive(:find).and_return(defn)
      allow(MatViews::Jobs::Adapter).to receive(:enqueue)
    end

    it 'enqueues CreateViewJob with queue and args, then redirects (303)' do
      post :create_now, params: { lang:, frame_id:, frame_action:, id: defn.id, force: 'true' }

      expect(controller).to have_received(:authorize_mat_views!).with(:create_view, defn)
      expect(MatViews::Jobs::Adapter).to have_received(:enqueue).with(
        MatViews::CreateViewJob,
        queue: 'default',
        args: [defn.id, true, :none]
      )
      expect(response).to have_http_status(:see_other)
      expect(response.location).to match(%r{/admin/definitions/#{defn.id}\?})
    end
  end

  describe 'POST #refresh' do
    let(:defn) { create(:mat_view_definition) }

    before do
      allow(MatViews::MatViewDefinition).to receive(:find).and_return(defn)
      allow(MatViews::Jobs::Adapter).to receive(:enqueue)
    end

    it 'enqueues RefreshViewJob and redirects (303)' do
      post :refresh, params: { lang:, frame_id:, frame_action:, id: defn.id }

      expect(controller).to have_received(:authorize_mat_views!).with(:refresh, defn)
      expect(MatViews::Jobs::Adapter).to have_received(:enqueue).with(
        MatViews::RefreshViewJob,
        queue: 'default',
        args: [defn.id, :none]
      )
      expect(response).to have_http_status(:see_other)
      expect(response.location).to match(%r{/admin/definitions/#{defn.id}\?})
    end
  end

  describe 'POST #delete_now' do
    let(:defn) { create(:mat_view_definition) }

    before do
      allow(MatViews::MatViewDefinition).to receive(:find).and_return(defn)
      allow(MatViews::Jobs::Adapter).to receive(:enqueue)
    end

    it 'enqueues DeleteViewJob with cascade flag and redirects (303)' do
      post :delete_now, params: { lang:, frame_id:, frame_action:, id: defn.id, cascade: 'true' }

      expect(controller).to have_received(:authorize_mat_views!).with(:delete_view, defn)
      expect(MatViews::Jobs::Adapter).to have_received(:enqueue).with(
        MatViews::DeleteViewJob,
        queue: 'default',
        args: [defn.id, true, :none]
      )
      expect(response).to have_http_status(:see_other)
      expect(response.location).to match(%r{/admin/definitions/#{defn.id}\?})
    end
  end

  describe '#handle_frame_response' do
    let(:defn) { create(:mat_view_definition) }

    before do
      allow(MatViews::MatViewDefinition).to receive(:find).and_return(defn)
      allow(controller).to receive(:render)
      allow(MatViews::Jobs::Adapter).to receive(:enqueue)
    end

    context "when frame_id == 'dash-definitions'" do
      it 'redirects to index with 303' do
        post :create_now, params: { lang:, frame_id: 'dash-definitions', frame_action:, id: defn.id }
        expect(response).to have_http_status(:see_other)
        expect(response.location).to match(%r{/admin/definitions\?})
      end
    end

    context "when frame_id != 'dash-definitions'" do
      it 'renders empty with 303' do
        post :create_now, params: { lang:, frame_id:, frame_action:, id: defn.id }
        expect(response).to have_http_status(:see_other)
        expect(response.location).to match(%r{/admin/definitions/#{defn.id}\?})
      end
    end
  end
end
