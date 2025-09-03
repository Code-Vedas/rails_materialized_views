# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

require 'rails_helper'

RSpec.describe MatViews::CreateViewJob, type: :job do
  before do
    ActiveJob::Base.queue_adapter = :test

    MatViews.configure do |c|
      c.job_queue = :mat_views_test
    end
  end

  let!(:definition) do
    create(
      :mat_view_definition,
      name: 'mv_runner_job_spec',
      sql: 'SELECT 1 AS id',
      refresh_strategy: :regular
    )
  end

  def service_response_double(status:, request: {}, response: {}, error: nil)
    success = (status != :error)
    instance_double(
      MatViews::ServiceResponse,
      status: status,
      request: request,
      response: response,
      error: error,
      success?: success,
      error?: !success,
      to_h: { status: status, request: request, response: response, error: error }.compact
    )
  end

  describe 'queueing' do
    it 'enqueues on the configured queue' do
      expect do
        described_class.perform_later(definition.id, force: true)
      end.to have_enqueued_job(described_class)
        .on_queue('mat_views_test')
        .with(definition.id, force: true)
    end
  end

  describe '#perform' do
    context 'when the service returns success' do
      it 'returns the response hash' do
        resp = service_response_double(status: :created, request: { view: 'public.mv' }, response: { rows: 100 })
        svc  = instance_spy(MatViews::Services::CreateView, run: resp)
        allow(MatViews::Services::CreateView)
          .to receive(:new).with(definition, force: true, row_count_strategy: :none).and_return(svc)

        result = perform_now_and_return(definition.id, force: true)
        expect(result).to eq(resp.to_h)
      end

      it 'records a successful create run with core fields set' do
        resp = service_response_double(status: :created, response: { view: 'public.mv' })
        svc  = instance_spy(MatViews::Services::CreateView, run: resp)
        allow(MatViews::Services::CreateView)
          .to receive(:new).with(definition, force: true, row_count_strategy: :none).and_return(svc)

        perform_now_and_return(definition.id, force: true)

        run    = MatViews::MatViewRun.create_runs.order(created_at: :desc).first
        fields = run.attributes.slice('mat_view_definition_id', 'status', 'error')
        expect(fields).to eq(
          'mat_view_definition_id' => definition.id,
          'status' => 'success',
          'error' => nil
        )
      end

      it 'persists timing and meta' do
        resp = service_response_double(status: :created, response: { view: 'public.mv' })
        svc  = instance_spy(MatViews::Services::CreateView, run: resp)
        allow(MatViews::Services::CreateView)
          .to receive(:new).with(definition, force: true, row_count_strategy: :none).and_return(svc)

        perform_now_and_return(definition.id, force: true)

        run = MatViews::MatViewRun.create_runs.order(created_at: :desc).first
        expect(run.meta).to include({ 'response' => { 'view' => 'public.mv' } })
        expect([run.started_at.present?, run.finished_at.present?, run.duration_ms.is_a?(Integer)]).to eq([true, true, true])
      end
    end

    context 'when the service returns error (no raise)' do
      it 'returns the response hash and records failed run' do
        resp = service_response_double(status: :error, error: StandardError.new('Invalid SQL').mv_serialize_error)
        svc  = instance_spy(MatViews::Services::CreateView, run: resp)
        allow(MatViews::Services::CreateView)
          .to receive(:new).with(definition, force: false, row_count_strategy: :none).and_return(svc)

        result = perform_now_and_return(definition.id)
        expect(result).to eq(resp.to_h)

        run = MatViews::MatViewRun.create_runs.order(created_at: :desc).first
        expect(run.status).to eq('failed')
        expect(run.error['message']).to match(/Invalid SQL/)
        expect(run.error['class']).to eq('StandardError')
        expect(run.error['backtrace']).to be_an(Array)
      end
    end

    context 'when the service raises' do
      it 're-raises and marks the run failed' do
        svc = instance_spy(MatViews::Services::CreateView)
        allow(MatViews::Services::CreateView)
          .to receive(:new).with(definition, force: false, row_count_strategy: :none).and_return(svc)
        allow(svc).to receive(:run).and_raise(StandardError, 'kaboom')

        expect do
          perform_now_and_return(definition.id)
        end.to raise_error(Minitest::UnexpectedError, /kaboom/)

        run    = MatViews::MatViewRun.create_runs.order(created_at: :desc).first
        expect(run.status).to eq('failed')
        expect(run.error['message']).to match(/kaboom/)
        expect(run.error['class']).to eq('StandardError')
        expect(run.error['backtrace']).to be_an(Array)
      end
    end

    context 'when run fails to save' do
      it 'raises and does not attempt to update the run' do
        resp = service_response_double(status: :created, response: { view: 'public.mv' })
        svc  = instance_spy(MatViews::Services::CreateView, run: resp)
        allow(MatViews::Services::CreateView)
          .to receive(:new).with(definition, force: false, row_count_strategy: :none).and_return(svc)

        allow(MatViews::MatViewRun).to receive(:create!).and_raise(ActiveRecord::RecordInvalid)

        expect do
          perform_now_and_return(definition.id)
        end.to raise_error(Minitest::UnexpectedError)

        expect(MatViews::MatViewRun).to have_received(:create!).once
      end
    end
  end

  # helpers
  def perform_now_and_return(*args)
    performed = nil
    perform_enqueued_jobs { performed = described_class.perform_now(*args) }
    performed
  end
end
