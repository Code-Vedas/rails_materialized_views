# frozen_string_literal: true

RSpec.describe MatViews::Configuration do
  subject(:configuration) { MatViews.configuration }

  describe '#initialize' do
    it 'sets default values' do
      expect(configuration.retry_on_failure).to be true
      expect(configuration.job_adapter).to eq :active_job
      expect(configuration.job_queue).to eq :default
    end
  end

  describe '#retry_on_failure' do
    it 'can be set and retrieved' do
      MatViews.configure do |config|
        config.retry_on_failure = false
      end

      expect(configuration.retry_on_failure).to be false
    end
  end

  describe '#job_adapter' do
    it 'can be set and retrieved' do
      MatViews.configure do |config|
        config.job_adapter = :sidekiq
      end

      expect(configuration.job_adapter).to eq :sidekiq
    end
  end

  describe '#job_queue' do
    it 'can be set and retrieved' do
      MatViews.configure do |config|
        config.job_queue = :custom_queue
      end

      expect(configuration.job_queue).to eq :custom_queue
    end
  end
end
