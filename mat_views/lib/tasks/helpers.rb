# frozen_string_literal: true

require 'logger'

module MatViews
  module Tasks
    # Helper methods for mat_views Rake tasks.
    module Helpers
      module_function

      def mv_conn
        ActiveRecord::Base.connection
      end

      def logger
        Rails.logger
      end

      def booleanish_true?(value)
        str = value.to_s.strip.downcase
        %w[1 true yes y --yes].include?(str)
      end

      def skip_confirm?(arg)
        booleanish_true?(arg || ENV.fetch('YES', nil))
      end

      def parse_force?(arg)
        booleanish_true?(arg || ENV.fetch('FORCE', nil))
      end

      def parse_row_count_strategy(arg)
        s = (arg || ENV.fetch('ROW_COUNT_STRATEGY', nil)).to_s.strip
        return :estimated if s.empty?

        s.to_sym
      end

      def matview_exists?(rel, schema: 'public')
        mv_conn.select_value(<<~SQL).to_i.positive?
          SELECT COUNT(*)
          FROM pg_matviews
          WHERE schemaname = #{mv_conn.quote(schema)} AND matviewname = #{mv_conn.quote(rel)}
        SQL
      end

      def find_definition_by_name!(raw_name)
        raise 'view_name is required' if raw_name.nil? || raw_name.to_s.strip.empty?

        schema, rel =
          if raw_name.to_s.include?('.')
            parts = raw_name.to_s.split('.', 2)
            [parts[0], parts[1]]
          else
            [nil, raw_name.to_s]
          end

        defn = MatViews::MatViewDefinition.find_by(name: rel)
        return defn if defn

        if schema && matview_exists?(rel, schema: schema)
          raise "Materialized view #{schema}.#{rel} exists, but no MatViews::MatViewDefinition record was found for name=#{rel.inspect}"
        end

        raise "No MatViews::MatViewDefinition found for #{raw_name.inspect}"
      end

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

      def enqueue_create!(definition_id, force)
        q = MatViews.configuration.job_queue || :default
        MatViews::Jobs::Adapter.enqueue(
          MatViews::CreateViewJob,
          queue: q,
          args: [definition_id, force]
        )
      end

      def enqueue_refresh!(definition_id, row_count_strategy)
        q = MatViews.configuration.job_queue || :default
        MatViews::Jobs::Adapter.enqueue(
          MatViews::RefreshViewJob,
          queue: q,
          args: [definition_id, row_count_strategy]
        )
      end
    end
  end
end
