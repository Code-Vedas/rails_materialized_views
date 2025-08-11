# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

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
      @job_queue = :default
    end
  end
end
