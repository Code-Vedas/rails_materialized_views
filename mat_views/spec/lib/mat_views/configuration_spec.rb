# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

RSpec.describe MatViews::Configuration do
  subject(:configuration) { MatViews.configuration }

  describe '#initialize' do
    it 'sets default values' do
      expect(configuration.job_adapter).to eq :active_job
      expect(configuration.job_queue).to eq :default
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
