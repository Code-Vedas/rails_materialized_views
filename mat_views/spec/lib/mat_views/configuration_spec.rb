# frozen_string_literal: true

RSpec.describe MatViews::Configuration do
  it 'sets and reads configuration values' do
    MatViews.configure do |config|
      config.refresh_strategy = :cron
    end

    expect(MatViews.configuration.refresh_strategy).to eq(:cron)
  end
end
