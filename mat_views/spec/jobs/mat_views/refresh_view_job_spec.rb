# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

require 'rails_helper'

RSpec.describe MatViews::RefreshViewJob, type: :job do
  before do
    ActiveJob::Base.queue_adapter = :test

    MatViews.configure do |c|
      c.job_queue = :mat_views_test
    end
  end

  let!(:definition_regular) do
    create(
      :mat_view_definition,
      name: 'mv_refresh_runner_job_spec',
      sql: 'SELECT 1 AS id',
      refresh_strategy: :regular
    )
  end

  let!(:definition_concurrent) do
    create(
      :mat_view_definition,
      name: 'mv_concurrent_refresh_runner_job_spec',
      sql: 'SELECT 1 AS id',
      refresh_strategy: :concurrent,
      unique_index_columns: %w[id]
    )
  end

  let!(:definition_swap) do
    create(
      :mat_view_definition,
      name: 'mv_swap_refresh_runner_job_spec',
      sql: 'SELECT 1 AS id',
      refresh_strategy: :swap,
      unique_index_columns: []
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

  shared_examples 'a refresh job' do
    describe 'queueing' do
      it 'enqueues on the configured queue (hash arg)' do
        expect do
          described_class.perform_later(definition.id, row_count_strategy: :exact)
        end.to have_enqueued_job(described_class)
          .on_queue('mat_views_test')
          .with(definition.id, row_count_strategy: :exact)
      end

      it 'enqueues on the configured queue (bare symbol arg)' do
        expect do
          described_class.perform_later(definition.id, :estimated)
        end.to have_enqueued_job(described_class)
          .on_queue('mat_views_test')
          .with(definition.id, :estimated)
      end
    end

    describe '#perform' do
      context 'when the service returns success' do
        it 'returns the response hash' do
          resp = service_response_double(status: :updated, payload: { view: 'public.mv' })
          svc  = instance_spy(svc_class, run: resp)
          allow(svc_class).to receive(:new).with(definition, row_count_strategy: :exact).and_return(svc)

          result = perform_now_and_return(definition.id, row_count_strategy: :exact)
          expect(result).to eq(resp.to_h)
        end

        it 'records a successful refresh run with core fields set' do
          resp = service_response_double(status: :updated, payload: { view: 'public.mv' })
          svc  = instance_spy(svc_class, run: resp)
          allow(svc_class).to receive(:new).with(definition, row_count_strategy: :estimated).and_return(svc)

          perform_now_and_return(definition.id)

          run    = MatViews::MatViewRefreshRun.order(created_at: :desc).first
          fields = run.attributes.slice('mat_view_definition_id', 'status', 'error')
          expect(fields).to eq(
            'mat_view_definition_id' => definition.id,
            'status' => 'success',
            'error' => nil
          )
        end

        it 'persists timing and meta' do
          resp = service_response_double(status: :updated, payload: { view: 'public.mv', rows_count: 1 })
          svc  = instance_spy(svc_class, run: resp)
          allow(svc_class).to receive(:new).with(definition, row_count_strategy: :estimated).and_return(svc)

          perform_now_and_return(definition.id)

          run = MatViews::MatViewRefreshRun.order(created_at: :desc).first
          expect(run.meta).to include('view' => 'public.mv', 'rows_count' => 1)
          expect([run.started_at.present?, run.finished_at.present?, run.duration_ms.is_a?(Integer)]).to eq([true, true, true])
        end
      end

      context 'when the service returns error (no raise)' do
        it 'returns the response hash and records failed run' do
          resp = service_response_double(status: :error, error: 'View missing')
          svc  = instance_spy(svc_class, run: resp)
          allow(svc_class).to receive(:new).with(definition, row_count_strategy: :estimated).and_return(svc)

          result = perform_now_and_return(definition.id)
          expect(result).to eq(resp.to_h)

          run    = MatViews::MatViewRefreshRun.order(created_at: :desc).first
          fields = run.attributes.slice('status', 'error')
          expect(fields['status']).to eq('failed')
          expect(fields['error']).to match(/View missing/)
        end
      end

      context 'when the service raises' do
        it 're-raises and marks the run failed' do
          svc = instance_spy(svc_class)
          allow(svc_class).to receive(:new).with(definition, row_count_strategy: :estimated).and_return(svc)
          allow(svc).to receive(:run).and_raise(StandardError, 'kaboom')

          expect do
            perform_now_and_return(definition.id)
          end.to raise_error(Minitest::UnexpectedError, /kaboom/)

          run    = MatViews::MatViewRefreshRun.order(created_at: :desc).first
          fields = run.attributes.slice('status', 'error')
          expect(fields['status']).to eq('failed')
          expect(fields['error']).to match(/StandardError: kaboom/)
        end
      end

      context 'when run fails to save' do
        it 'raises and does not attempt to update the run' do
          resp = service_response_double(status: :updated, payload: { view: 'public.mv' })
          svc  = instance_spy(svc_class, run: resp)
          allow(svc_class).to receive(:new).with(definition, row_count_strategy: :estimated).and_return(svc)

          allow(MatViews::MatViewRefreshRun).to receive(:create!).and_raise(ActiveRecord::RecordInvalid)

          expect do
            perform_now_and_return(definition.id)
          end.to raise_error(Minitest::UnexpectedError)

          expect(MatViews::MatViewRefreshRun).to have_received(:create!).once
        end
      end

      describe 'strategy normalization' do
        it 'accepts a bare symbol' do
          resp = service_response_double(status: :updated)
          svc  = instance_spy(svc_class, run: resp)
          allow(svc_class).to receive(:new).with(definition, row_count_strategy: :exact).and_return(svc)
          perform_now_and_return(definition.id, :exact)

          expect(svc_class).to have_received(:new).with(definition, row_count_strategy: :exact).once
          expect(svc).to have_received(:run).once
        end

        it 'accepts a string' do
          resp = service_response_double(status: :updated)
          svc  = instance_spy(svc_class, run: resp)
          allow(svc_class).to receive(:new).with(definition, row_count_strategy: :estimated).and_return(svc)
          perform_now_and_return(definition.id, 'estimated')

          expect(svc_class).to have_received(:new).with(definition, row_count_strategy: :estimated).once

          expect(svc).to have_received(:run).once
        end

        it 'accepts a hash with :row_count_strategy / :strategy keys' do
          resp = service_response_double(status: :updated)
          svc1 = instance_spy(svc_class, run: resp)
          allow(svc_class).to receive(:new).with(definition, row_count_strategy: :exact).and_return(svc1)
          perform_now_and_return(definition.id, row_count_strategy: :exact)

          svc2 = instance_spy(svc_class, run: resp)
          allow(svc_class).to receive(:new).with(definition, row_count_strategy: :exact).and_return(svc2)
          perform_now_and_return(definition.id, strategy: :exact)

          expect(svc_class).to have_received(:new).with(definition, row_count_strategy: :exact).twice

          expect(svc1).to have_received(:run).once
          expect(svc2).to have_received(:run).once
        end
      end
    end
  end

  context 'when the definition uses regular refresh' do
    let(:definition) { definition_regular }
    let(:svc_class) { MatViews::Services::RegularRefresh }

    it_behaves_like 'a refresh job'
  end

  context 'when the definition uses concurrent refresh' do
    let(:definition) { definition_concurrent }
    let(:svc_class) { MatViews::Services::ConcurrentRefresh }

    it_behaves_like 'a refresh job'
  end

  context 'when the definition uses swap refresh' do
    let(:definition) { definition_swap }
    let(:svc_class) { MatViews::Services::SwapRefresh }

    it_behaves_like 'a refresh job'
  end

  # helpers
  def perform_now_and_return(*args)
    performed = nil
    perform_enqueued_jobs { performed = described_class.perform_now(*args) }
    performed
  end
end
