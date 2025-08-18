# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

MatViews.configure do |config|
  ### Job Adapter Configuration
  # Set job adapter for MatViews
  # This can be set to :active_job, :sidekiq, and :resque,
  # defaults to :active_job.
  #
  # Depending on your application's job processing setup.
  # Uncomment the line below to set the job adapter.
  # config.job_adapter = :active_job

  # job_queue is the queue name for the job adapter.
  # Default is :default.
  # This is used to specify the queue where MatViews jobs will be enqueued.
  # Uncomment the line below to set the job queue.
  # config.job_queue = :default
end
