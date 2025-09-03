# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

##
# Top-level namespace for the mat_views engine.
module MatViews
  ##
  # Namespace for job-related utilities and integrations.
  module Jobs
    ##
    # Adapter class for handling job enqueuing across different backends.
    #
    # This class abstracts the job enqueueing process so MatViews can work
    # with multiple background processing frameworks without changing core code.
    #
    # Supported adapters (configured via `MatViews.configuration.job_adapter`):
    # - `:active_job` → {ActiveJob}
    # - `:sidekiq`   → {Sidekiq::Client}
    # - `:resque`    → {Resque}
    #
    # @example Enqueue via ActiveJob
    #   MatViews.configuration.job_adapter = :active_job
    #   MatViews::Jobs::Adapter.enqueue(MyJob, queue: :low, args: [1, "foo"])
    #
    # @example Enqueue via Sidekiq
    #   MatViews.configuration.job_adapter = :sidekiq
    #   MatViews::Jobs::Adapter.enqueue(MyWorker, queue: :critical, args: [42])
    #
    # @example Enqueue via Resque
    #   MatViews.configuration.job_adapter = :resque
    #   MatViews::Jobs::Adapter.enqueue(MyWorker, queue: :default, args: %w[a b c])
    #
    # @raise [ArgumentError] if the configured adapter is not recognized
    #
    class Adapter
      ##
      # Enqueue a job across supported backends.
      #
      # @api public
      #
      # @param job_class [Class] The job or worker class to enqueue.
      #   - For `:active_job`, this should be a subclass of {ActiveJob::Base}.
      #   - For `:sidekiq`, this should be a Sidekiq worker class.
      #   - For `:resque`, this should be a Resque worker class.
      #
      # @param queue [String, Symbol] Target queue name.
      # @param args [Array] Arguments to pass into the job/worker.
      #
      # @return [Object] Framework-dependent:
      #   - For ActiveJob → enqueued {ActiveJob::Base} instance
      #   - For Sidekiq → job ID hash
      #   - For Resque → `true` if enqueue succeeded
      #
      # @raise [ArgumentError] if the configured adapter is not recognized.
      #
      def self.enqueue(job_class, queue:, args: [])
        queue_str = queue.to_s
        job_adapter = MatViews.configuration.job_adapter

        case job_adapter
        when :active_job
          job_class.set(queue: queue_str).perform_later(*args)
        when :sidekiq
          Sidekiq::Client.push(
            'class' => job_class.name,
            'queue' => queue_str,
            'args' => args
          )
        when :resque
          Resque.enqueue_to(queue_str, job_class, *args)
        else
          raise ArgumentError, "Unknown job adapter: #{job_adapter.inspect}"
        end
      end
    end
  end
end
