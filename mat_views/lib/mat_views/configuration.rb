# frozen_string_literal: true

module MatViews
  # Configuration class for MatViews
  #
  # This class allows customization of the MatViews engine's behavior,
  # such as setting the default refresh strategy, retry behavior, and cron schedule.
  class Configuration
    attr_accessor :refresh_strategy, :retry_on_failure, :default_cron

    def initialize
      @refresh_strategy = :manual
      @retry_on_failure = true
      @default_cron = '0 * * * *'
    end
  end
end
