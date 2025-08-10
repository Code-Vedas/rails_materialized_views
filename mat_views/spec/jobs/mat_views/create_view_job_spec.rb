# frozen_string_literal: true

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

  def service_response_double(status:, payload: {}, error: nil)
    success = (status != :error)
    instance_double(
      MatViews::ServiceResponse,
      status: status,
      payload: payload,
      error: error,
      success?: success,
      error?: !success,
      to_h: { status: status, payload: payload, error: error }.compact
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
        resp = service_response_double(status: :created, payload: { view: 'public.mv' })
        svc  = instance_spy(MatViews::Services::CreateView, run: resp)
        allow(MatViews::Services::CreateView)
          .to receive(:new).with(definition, force: true).and_return(svc)

        result = perform_now_and_return(definition.id, force: true)
        expect(result).to eq(resp.to_h)
      end

      it 'records a successful create run with core fields set' do
        resp = service_response_double(status: :created, payload: { view: 'public.mv' })
        svc  = instance_spy(MatViews::Services::CreateView, run: resp)
        allow(MatViews::Services::CreateView)
          .to receive(:new).with(definition, force: true).and_return(svc)

        perform_now_and_return(definition.id, force: true)

        run    = MatViews::MatViewCreateRun.order(created_at: :desc).first
        fields = run.attributes.slice('mat_view_definition_id', 'status', 'error')
        expect(fields).to eq(
          'mat_view_definition_id' => definition.id,
          'status' => 'success',
          'error' => nil
        )
      end

      it 'persists timing and meta' do
        resp = service_response_double(status: :created, payload: { view: 'public.mv' })
        svc  = instance_spy(MatViews::Services::CreateView, run: resp)
        allow(MatViews::Services::CreateView)
          .to receive(:new).with(definition, force: true).and_return(svc)

        perform_now_and_return(definition.id, force: true)

        run = MatViews::MatViewCreateRun.order(created_at: :desc).first
        expect(run.meta).to include('view' => 'public.mv')
        expect([run.started_at.present?, run.finished_at.present?, run.duration_ms.is_a?(Integer)]).to eq([true, true, true])
      end
    end

    context 'when the service returns error (no raise)' do
      it 'returns the response hash and records failed run' do
        resp = service_response_double(status: :error, error: 'Invalid SQL')
        svc  = instance_spy(MatViews::Services::CreateView, run: resp)
        allow(MatViews::Services::CreateView)
          .to receive(:new).with(definition, force: false).and_return(svc)

        result = perform_now_and_return(definition.id)
        expect(result).to eq(resp.to_h)

        run    = MatViews::MatViewCreateRun.order(created_at: :desc).first
        fields = run.attributes.slice('status', 'error')
        expect(fields['status']).to eq('failed')
        expect(fields['error']).to match(/Invalid SQL/)
      end
    end

    context 'when the service raises' do
      it 're-raises and marks the run failed' do
        svc = instance_spy(MatViews::Services::CreateView)
        allow(MatViews::Services::CreateView)
          .to receive(:new).with(definition, force: false).and_return(svc)
        allow(svc).to receive(:run).and_raise(StandardError, 'kaboom')

        expect do
          perform_now_and_return(definition.id)
        end.to raise_error(Minitest::UnexpectedError, /kaboom/)

        run    = MatViews::MatViewCreateRun.order(created_at: :desc).first
        fields = run.attributes.slice('status', 'error')
        expect(fields['status']).to eq('failed')
        expect(fields['error']).to match(/StandardError: kaboom/)
      end
    end

    context 'when run fails to save' do
      it 'raises and does not attempt to update the run' do
        resp = service_response_double(status: :created, payload: { view: 'public.mv' })
        svc  = instance_spy(MatViews::Services::CreateView, run: resp)
        allow(MatViews::Services::CreateView)
          .to receive(:new).with(definition, force: false).and_return(svc)

        allow(MatViews::MatViewCreateRun).to receive(:create!).and_raise(ActiveRecord::RecordInvalid)

        expect do
          perform_now_and_return(definition.id)
        end.to raise_error(Minitest::UnexpectedError)

        expect(MatViews::MatViewCreateRun).to have_received(:create!).once
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
