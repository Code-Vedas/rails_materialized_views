# frozen_string_literal: true

module MatViews
  module Jobs
    # Adapter class for handling job enqueuing across different backends.
    #
    # This class abstracts the job enqueuing process, allowing MatViews to work
    # with various job processing libraries like ActiveJob, Sidekiq, and Resque.
    #
    # Usage:
    #   MatViews::Jobs::Adapter.enqueue(MyJobClass, queue: :my_queue, args: [arg1, arg2])
    #
    # This will enqueue the job using the configured job adapter.
    #
    # Supported job adapters:
    # - :active_job
    # - :sidekiq
    # - :resque
    #
    # If an unsupported adapter is configured, an ArgumentError will be raised.
    class Adapter
      # Public: enqueue a job across supported backends.
      # @param job_class [Class] the job/wrapper class
      # @param queue [String, Symbol] target queue
      # @param args [Array] arguments to pass into the job
      def self.enqueue(job_class, queue:, args: [])
        case MatViews.configuration.job_adapter
        when :active_job
          job_class.set(queue: queue.to_s).perform_later(*args)
        when :sidekiq
          Sidekiq::Client.push(
            'class' => job_class.name,
            'queue' => queue.to_s,
            'args' => args
          )
        when :resque
          Resque.enqueue_to(queue.to_s, job_class.to_s, *args)
        else
          raise ArgumentError, "Unknown job adapter: #{MatViews.configuration.job_adapter.inspect}"
        end
      end
    end
  end
end
