# frozen_string_literal: true

module MatViews
  # Configuration class for MatViews
  #
  # This class allows customization of the MatViews engine's behavior,
  # such as setting the default refresh strategy, retry behavior, and cron schedule.
  class Configuration
    attr_accessor :retry_on_failure, :job_adapter, :job_queue

    def initialize
      @retry_on_failure = true
      @job_adapter = :active_job
      @job_queue = :mat_views
    end
  end
end
