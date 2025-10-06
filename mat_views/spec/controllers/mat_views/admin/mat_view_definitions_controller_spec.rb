# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

RSpec.describe MatViews::Admin::MatViewDefinitionsController, type: :controller do
  routes { MatViews::Engine.routes }

  let(:lang)         { I18n.locale.to_s }
  let(:frame_id)     { 'some-frame' }

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
    let(:defn_one) { create(:mat_view_definition, name: 'A', schedule_cron: '0 0 *') }
    let(:defn_two) { create(:mat_view_definition, name: 'B', refresh_strategy: :swap) }
    let(:definitions) { [defn_one, defn_two] }
    let(:service_response_one) { instance_double(MatViews::ServiceResponse, response: { exists: true }) }
    let(:service_response_two) { instance_double(MatViews::ServiceResponse, response: { exists: false }) }
    let(:checker_one) { instance_double(MatViews::Services::CheckMatviewExists, call: service_response_one) }
    let(:checker_two) { instance_double(MatViews::Services::CheckMatviewExists, call: service_response_two) }

    before do
      allow(MatViews::Services::CheckMatviewExists).to receive(:new).with(defn_one).and_return(checker_one)
      allow(MatViews::Services::CheckMatviewExists).to receive(:new).with(defn_two).and_return(checker_two)
      allow(controller).to receive(:render)
      get :index, params: { lang:, frame_id: }
    end

    it 'authorizes and assigns @definitions and @mv_exists_map' do
      expect(controller).to have_received(:authorize_mat_views!).with(:read, :mat_views_definitions)
      expect(controller.instance_variable_get(:@data)).to eq(definitions)
      expect(controller.instance_variable_get(:@row_meta)).to eq({ mv_exists_map: { 'A' => true, 'B' => false } })
    end

    it 'renders the turbo frame layout' do
      expect(controller).to have_received(:render).with('index',
                                                        formats: :html,
                                                        layout: 'mat_views/turbo_frame',
                                                        locals: { row_meta: { mv_exists_map: { 'A' => true, 'B' => false } } })
      expect(response).to be_successful
    end

    context 'when dtsort=name:asc is provided' do
      before do
        get :index, params: { lang:, frame_id:, dtsort: 'name:asc' }
      end

      it 'sorts definitions by name ascending' do
        expect(controller.instance_variable_get(:@data)).to eq([defn_one, defn_two])
      end
    end

    context 'when dtsort=name:desc is provided' do
      before do
        get :index, params: { lang:, frame_id:, dtsort: 'name:desc' }
      end

      it 'sorts definitions by name descending' do
        expect(controller.instance_variable_get(:@data)).to eq([defn_two, defn_one])
      end
    end

    context 'when dtsort=refresh_strategy:asc is provided' do
      before do
        get :index, params: { lang:, frame_id:, dtsort: 'refresh_strategy:asc' }
      end

      it 'sorts definitions by refresh_strategy ascending' do
        expect(controller.instance_variable_get(:@data)).to eq([defn_one, defn_two])
      end
    end

    context 'when dtsort=refresh_strategy:desc is provided' do
      before do
        get :index, params: { lang:, frame_id:, dtsort: 'refresh_strategy:desc' }
      end

      it 'sorts definitions by refresh_strategy descending' do
        expect(controller.instance_variable_get(:@data)).to eq([defn_two, defn_one])
      end
    end

    context 'when dtsort=schedule_cron:asc is provided' do
      before do
        get :index, params: { lang:, frame_id:, dtsort: 'schedule_cron:asc' }
      end

      it 'sorts definitions by schedule_cron ascending' do
        expect(controller.instance_variable_get(:@data)).to eq([defn_one, defn_two])
      end
    end

    context 'when dtsort=schedule_cron:desc is provided' do
      before do
        get :index, params: { lang:, frame_id:, dtsort: 'schedule_cron:desc' }
      end

      it 'sorts definitions by schedule_cron descending' do
        expect(controller.instance_variable_get(:@data)).to eq([defn_one, defn_two])
      end
    end

    context 'when dtsort=last_run_at:asc is provided' do
      before do
        get :index, params: { lang:, frame_id:, dtsort: 'last_run_at:asc' }
      end

      it 'sorts definitions by last_run_at ascending' do
        expect(controller.instance_variable_get(:@data)).to eq([defn_one, defn_two])
      end
    end

    context 'when dtsort=last_run_at:desc is provided' do
      before do
        get :index, params: { lang:, frame_id:, dtsort: 'last_run_at:desc' }
      end

      it 'sorts definitions by last_run_at descending' do
        expect(controller.instance_variable_get(:@data)).to eq([defn_one, defn_two])
      end
    end

    context 'when dtfilter=name is provided' do
      before do
        get :index, params: { lang:, frame_id:, dtfilter: 'name:A' }
      end

      it 'filters definitions by name' do
        expect(controller.instance_variable_get(:@data)).to eq([defn_one])
      end
    end

    context 'when dtfilter=refresh_strategy is provided' do
      before do
        get :index, params: { lang:, frame_id:, dtfilter: 'refresh_strategy:regular' }
      end

      it 'filters definitions by refresh_strategy' do
        expect(controller.instance_variable_get(:@data)).to eq([defn_one])
      end
    end

    context 'when dtfilter=schedule_cron is provided' do
      before do
        get :index, params: { lang:, frame_id:, dtfilter: 'schedule_cron:0_0_*' }
      end

      it 'filters definitions by schedule_cron' do
        expect(controller.instance_variable_get(:@data)).to eq([defn_one])
      end
    end

    context 'when dtfilter=schedule_cron:no_value is provided' do
      before do
        get :index, params: { lang:, frame_id:, dtfilter: 'schedule_cron:no_value' }
      end

      it 'filters definitions by schedule_cron with no value' do
        expect(controller.instance_variable_get(:@data)).to eq([defn_two])
      end
    end

    context 'when dtsearch is provided' do
      before do
        get :index, params: { lang:, frame_id:, dtsearch: 'B' }
      end

      it 'searches definitions by name' do
        expect(controller.instance_variable_get(:@data)).to eq([defn_two])
      end
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
                s.include?('<turbo-stream action="replace" target="datatable-body-mv-definitions-table"')
              end && streams.any? do |s|
                s.include?('<turbo-stream action="replace" target="datatable-tfoot-mv-definitions-table"')
              end && streams.any? do |s|
                s.include?('<turbo-stream action="replace" target="datatable-filters-mv-definitions-table"')
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
                s.include?('<turbo-stream action="replace" target="datatable-body-mv-definitions-table"')
              end && streams.any? do |s|
                s.include?('<turbo-stream action="replace" target="datatable-tfoot-mv-definitions-table"')
              end && streams.none? do |s|
                s.include?('<turbo-stream action="replace" target="datatable-filters-mv-definitions-table"')
              end
            end
          )
        )
      end
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
      expect(controller).to have_received(:authorize_mat_views!).with(:read, :mat_views_definition, defn)
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
      get :new, params: { lang:, frame_id: }
    end

    it 'authorizes, builds a new definition and renders' do
      expect(controller).to have_received(:authorize_mat_views!).with(:create, :mat_views_definition)
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
      expect(controller).to have_received(:authorize_mat_views!).with(:update, :mat_views_definition, defn)
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
          lang:, frame_id:,
          mat_view_definition: normalized_params
        }
      end

      it 'authorizes, normalizes arrays, creates the record and redirects with status 298' do
        expect(controller).to have_received(:authorize_mat_views!).with(:create, :mat_views_definition)
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
          lang:, frame_id:,
          mat_view_definition: normalized_params
        }
      end

      it 'renders form with unprocessable status' do
        expect(controller).to have_received(:render).with(
          'form', formats: :html, layout: 'mat_views/turbo_frame', status: :unprocessable_content
        )
      end
    end

    context 'when unique_index_columns and dependencies are blank' do
      let(:normalized_params) do
        {
          'name' => 'orders_mv',
          'sql' => 'SELECT 1',
          'refresh_strategy' => 'regular',
          'schedule_cron' => '0 * * * *',
          'unique_index_columns' => ''
        }
      end

      let(:expected_attrs) do
        {
          'name' => 'orders_mv',
          'sql' => 'SELECT 1',
          'refresh_strategy' => 'regular',
          'schedule_cron' => '0 * * * *'
        }
      end

      let(:defn) { create(:mat_view_definition) }

      before do
        allow(MatViews::MatViewDefinition).to receive(:new)
          .with(hash_including(expected_attrs)).and_return(defn)
        allow(defn).to receive(:save).and_return(true)

        post :create, params: {
          lang:, frame_id:,
          mat_view_definition: normalized_params
        }
      end

      it 'authorizes, normalizes arrays, creates the record and redirects with status 298' do
        expect(controller).to have_received(:authorize_mat_views!).with(:create, :mat_views_definition)
        expect(response).to have_http_status(298)
        expect(response.location).to match(%r{/admin/definitions/#{defn.id}\?})
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
          lang:, frame_id:, id: defn.id,
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
          lang:, frame_id:, id: defn.id,
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
        delete :destroy, params: { lang:, frame_id: 'dash-definitions', id: defn.id }
      end

      it 'redirects to definitions index' do
        expect(response).to have_http_status(:see_other)
        expect(response.location).to match(%r{/admin/definitions\?})
      end
    end

    context "when frame_id != 'dash-definitions' renders empty with 298" do
      before do
        allow(controller).to receive(:render)
        delete :destroy, params: { lang:, frame_id:, id: defn.id }
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
      post :create_now, params: { lang:, frame_id:, id: defn.id, force: 'true' }

      expect(controller).to have_received(:authorize_mat_views!).with(:create, :mat_views_definition_view, defn)
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
      post :refresh, params: { lang:, frame_id:, id: defn.id }

      expect(controller).to have_received(:authorize_mat_views!).with(:update, :mat_views_definition_view, defn)
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
      post :delete_now, params: { lang:, frame_id:, id: defn.id, cascade: 'true' }

      expect(controller).to have_received(:authorize_mat_views!).with(:destroy, :mat_views_definition_view, defn)
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
        post :create_now, params: { lang:, frame_id: 'dash-definitions', id: defn.id }
        expect(response).to have_http_status(:see_other)
        expect(response.location).to match(%r{/admin/definitions\?})
      end
    end

    context "when frame_id != 'dash-definitions'" do
      it 'renders empty with 303' do
        post :create_now, params: { lang:, frame_id:, id: defn.id }
        expect(response).to have_http_status(:see_other)
        expect(response.location).to match(%r{/admin/definitions/#{defn.id}\?})
      end
    end
  end

  describe '#build_matview_exists_map' do
    context 'when definitions are present' do
      let(:defn_a) { create(:mat_view_definition, name: 'A') }
      let(:defn_b) { create(:mat_view_definition, name: 'B') }
      let(:definitions) { [defn_a, defn_b] }
      let(:service_response_a) { instance_double(MatViews::ServiceResponse, response: { exists: true }) }
      let(:service_response_b) { instance_double(MatViews::ServiceResponse, response: { exists: false }) }
      let(:checker_a) { instance_double(MatViews::Services::CheckMatviewExists, call: service_response_a) }
      let(:checker_b) { instance_double(MatViews::Services::CheckMatviewExists, call: service_response_b) }

      it 'returns a map of definition names to existence boolean' do
        allow(MatViews::Services::CheckMatviewExists).to receive(:new).with(defn_a).and_return(checker_a)
        allow(MatViews::Services::CheckMatviewExists).to receive(:new).with(defn_b).and_return(checker_b)

        result = controller.send(:build_matview_exists_map, definitions)
        expect(result).to eq({ 'A' => true, 'B' => false })
      end
    end

    context 'when definitions is empty' do
      it 'returns an empty map' do
        result = controller.send(:build_matview_exists_map, [])
        expect(result).to eq({})
      end
    end
  end
end
