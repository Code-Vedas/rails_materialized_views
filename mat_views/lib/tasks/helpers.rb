# frozen_string_literal: true

require 'logger'

module MatViews
  module Tasks
    ##
    # Helpers module provides utility methods for MatViews Rake tasks.
    #
    # These helpers support:
    # - Database connections
    # - Logging
    # - Parsing boolean/flag-like arguments
    # - Confirmation prompts
    # - Enqueueing background jobs for create, refresh, and delete operations
    # - Looking up materialized view definitions
    #
    # By extracting this logic, Rake tasks can remain clean and declarative.
    module Helpers
      module_function

      # Returns the current database connection.
      # @return [ActiveRecord::ConnectionAdapters::AbstractAdapter]
      def mv_conn
        ActiveRecord::Base.connection
      end

      # Returns the Rails logger.
      # @return [Logger]
      def logger
        Rails.logger
      end

      # Check if a value is a "truthy" boolean-like string.
      # Recognized: 1, true, yes, y, --yes
      # @param value [String, Boolean, nil]
      # @return [Boolean]
      def booleanish_true?(value)
        str = value.to_s.strip.downcase
        %w[1 true yes y --yes].include?(str)
      end

      # Whether confirmation should be skipped (YES env or arg).
      def skip_confirm?(arg)
        booleanish_true?(arg || ENV.fetch('YES', nil))
      end

      # Parse whether force mode is enabled (FORCE env or arg).
      def parse_force?(arg)
        booleanish_true?(arg || ENV.fetch('FORCE', nil))
      end

      # Parse row count strategy from arg or ROW_COUNT_STRATEGY env.
      # Defaults to :none if blank.
      def parse_row_count_strategy(arg)
        str = (arg || ENV.fetch('ROW_COUNT_STRATEGY', nil)).to_s.strip
        return :none if str.empty?

        str.to_sym
      end

      # Check if a materialized view exists in schema.
      # @param rel [String] relation name
      # @param schema [String] schema name
      # @return [Boolean]
      def matview_exists?(rel, schema: 'public')
        mv_conn.select_value(<<~SQL).to_i.positive?
          SELECT COUNT(*)
          FROM pg_matviews
          WHERE schemaname = #{mv_conn.quote(schema)} AND matviewname = #{mv_conn.quote(rel)}
        SQL
      end

      # Find a MatViewDefinition by raw name (schema.rel or rel).
      # Raises if none found or mismatch with DB presence.
      #
      # @param raw_name [String] schema-qualified or unqualified view name
      # @return [MatViews::MatViewDefinition]
      # @raise [RuntimeError] if no definition found or mismatch with DB
      def find_definition_by_name!(raw_name)
        raw_name_string = raw_name&.to_s&.strip
        raise 'view_name is required' unless raw_name_string && !raw_name_string.empty?

        schema, rel =
          if raw_name_string.include?('.')
            parts = raw_name_string.split('.', 2)
            [parts[0], parts[1]]
          else
            [nil, raw_name_string]
          end

        defn = MatViews::MatViewDefinition.find_by(name: rel)
        return defn if defn

        if schema && matview_exists?(rel, schema: schema)
          raise "Materialized view #{schema}.#{rel} exists, but no MatViews::MatViewDefinition record was found for name=#{rel.inspect}"
        end

        raise "No MatViews::MatViewDefinition found for #{raw_name.inspect}"
      end

      # Ask user to confirm a destructive action, unless skipped.
      #
      # @param message [String] confirmation message
      # @param skip [Boolean] whether to skip confirmation
      # @raise [RuntimeError] if user declines confirmation
      # @return [void]
      #
      # If `skip` is true, logs the message and returns without prompting.
      # Otherwise, prompts user for confirmation and raises if declined.
      def confirm!(message, skip: false)
        if skip
          logger.info("[mat_views] #{message} — confirmation skipped.")
          return
        end

        logger.info("[mat_views] #{message}")
        $stdout.print('Proceed? [y/N]: ')
        $stdout.flush
        ans = $stdin.gets&.strip&.downcase
        return if ans&.start_with?('y')

        raise 'Aborted.'
      end

      # Enqueue a CreateView job for given definition.
      #
      # @param definition_id [Integer] MatViewDefinition ID
      # @param force [Boolean] whether to force creation
      # @param row_count_strategy [Symbol] :estimated or :exact or :none
      # @return [void]
      def enqueue_create(definition_id, force, row_count_strategy)
        MatViews::Jobs::Adapter.enqueue(
          MatViews::CreateViewJob,
          queue: MatViews.configuration.job_queue || :default,
          args: [definition_id, force, row_count_strategy]
        )
      end

      # Enqueue a RefreshView job for given definition.
      #
      # @param definition_id [Integer] MatViewDefinition ID
      # @param row_count_strategy [Symbol] :estimated or :exact
      # @return [void]
      #
      # This method allows scheduling a refresh operation with the specified row count strategy.
      # It uses the configured job adapter to enqueue the job.
      def enqueue_refresh(definition_id, row_count_strategy)
        MatViews::Jobs::Adapter.enqueue(
          MatViews::RefreshViewJob,
          queue: MatViews.configuration.job_queue || :default,
          args: [definition_id, row_count_strategy]
        )
      end

      # Parse cascade option (CASCADE env or arg).
      #
      # @param arg [String, Boolean, nil] argument or environment variable value
      # @return [Boolean] true if cascade is enabled, false otherwise
      #
      # This method checks if the CASCADE option is set to true, allowing for cascading drops.
      # It defaults to the value of the CASCADE environment variable if not provided.
      def parse_cascade?(arg)
        booleanish_true?(arg || ENV.fetch('CASCADE', nil))
      end

      # Enqueue a DeleteView job for given definition.
      #
      # @param definition_id [Integer] MatViewDefinition ID
      # @param cascade [Boolean] whether to drop with CASCADE
      # @param row_count_strategy [Symbol] :estimated or :exact or :none
      # @return [void]
      #
      # This method schedules a job to delete the materialized view, optionally with CASCADE.
      # It uses the configured job adapter to enqueue the job.
      def enqueue_delete(definition_id, cascade, row_count_strategy)
        MatViews::Jobs::Adapter.enqueue(
          MatViews::DeleteViewJob,
          queue: MatViews.configuration.job_queue || :default,
          args: [definition_id, cascade, row_count_strategy]
        )
      end
    end
  end
end
