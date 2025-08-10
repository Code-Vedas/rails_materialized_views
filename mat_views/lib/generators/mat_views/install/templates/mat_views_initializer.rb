# frozen_string_literal: true

MatViews.configure do |config|
  # Set the retry behavior for MatViews, globally
  # This determines whether MatViews will retry failed refreshes.
  # Defaults to true.
  # Uncomment the line below to set retry behavior.
  # config.retry_on_failure = true

  ### Job Adapter Configuration
  # Set job adapter for MatViews
  # This can be set to :active_job, :sidekiq, and :resque,
  # defaults to :active_job.
  #
  # Depending on your application's job processing setup.
  # Uncomment the line below to set the job adapter.
  # config.job_adapter = :active_job

  # job_queue is the queue name for the job adapter.
  # Default is :mat_views.
  # This is used to specify the queue where MatViews jobs will be enqueued.
  # Uncomment the line below to set the job queue.
  # config.job_queue = :mat_views
end
