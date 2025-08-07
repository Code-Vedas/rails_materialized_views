# frozen_string_literal: true

MatViews.configure do |config|
  config.refresh_strategy = :manual
  config.retry_on_failure = true
  config.default_cron = '0 * * * *'
end
