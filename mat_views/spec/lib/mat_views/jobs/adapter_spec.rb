# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MatViews::Jobs::Adapter do
  let(:queue) { 'mat_views' }
  let(:args)  { ['def_123', { refresh: true }] }

  # A minimal AJ-compatible job class we can reuse across adapters.
  let(:job_class) do
    Class.new(ActiveJob::Base) do
      # give the anonymous class a stable name for matchers/logging
      def self.name = 'MatViews::Jobs::DummyWrapperJob'
      def perform(*_args); end
    end
  end

  describe 'ActiveJob', :active_job do
    before do
      MatViews.configure do |c|
        c.job_adapter = :active_job
        c.job_queue   = queue
      end
    end

    it 'enqueues our wrapper job on the configured queue' do
      expect do
        described_class.enqueue(job_class, queue: queue, args: args)
      end.to have_enqueued_job(job_class).with(*args).on_queue(queue)
    end
  end

  describe 'Sidekiq' do
    before do
      MatViews.configure do |c|
        c.job_adapter = :sidekiq
        c.job_queue   = queue
      end
    end

    it 'pushes to Sidekiq client with the correct payload' do
      # spy preferred over direct expectation
      allow(Sidekiq::Client).to receive(:push)

      described_class.enqueue(job_class, queue: queue, args: args)

      expect(Sidekiq::Client).to have_received(:push).with(
        hash_including(
          'class' => job_class,
          'queue' => queue,
          'args' => args
        )
      )
    end
  end

  describe 'Resque' do
    before do
      MatViews.configure do |c|
        c.job_adapter = :resque
        c.job_queue   = queue
      end
    end

    it 'enqueues to the right queue with expected args' do
      allow(Resque).to receive(:enqueue_to)

      described_class.enqueue(job_class, queue: queue, args: args)

      expect(Resque).to have_received(:enqueue_to).with(queue, job_class, *args)
    end
  end
end
