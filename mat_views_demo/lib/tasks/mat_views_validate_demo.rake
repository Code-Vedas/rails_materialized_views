# frozen_string_literal: true

require 'rake'
require 'csv'
require 'fileutils'

# Validate MV performance vs baseline SQL and write a CSV report.
# Usage:
#   bundle exec rake mat_views:validate_demo[iterations]
# Examples:
#   bundle exec rake mat_views:validate_demo[5]
#   bundle exec rake mat_views:validate_demo            # defaults to 5
namespace :mat_views do
  desc 'Benchmark baseline vs MV and write CSV (mat_views:validate_demo[iterations])'
  task :validate_demo, [:iterations] => :environment do |_t, args|
    iterations = (args[:iterations] || ENV['ITER'] || 5).to_i
    iterations = 1 if iterations < 1

    conn = ActiveRecord::Base.connection

    # Discover all materialised views present in the DB (exclude system schemas)
    rows = conn.select_all(<<~SQL.squish)
      SELECT schemaname, matviewname
      FROM pg_matviews
      WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
      ORDER BY schemaname, matviewname
    SQL

    mv_names = rows.rows.map { |(_, name)| name }.uniq
    if mv_names.empty?
      Rails.logger.info('[validate_demo] No materialised views found in the database. Nothing to validate.')
      next
    end

    # Fetch definitions that match actual MV names (needed to get baseline SQL)
    definitions = MatViews::MatViewDefinition.where(name: mv_names).order(:name).to_a
    if definitions.empty?
      Rails.logger.info('[validate_demo] Found MVs in DB, but no matching MatViewDefinition records. Nothing to validate.')
      next
    end

    # Report location
    ts_dir = File.join('tmp', 'mv_validate', Time.now.utc.strftime('%Y%m%d%H%M%S'))
    FileUtils.mkdir_p(ts_dir)
    out_csv = File.join(ts_dir, 'report.csv')

    headers = %w[
      view
      iterations
      baseline_avg_ms baseline_min_ms baseline_max_ms
      mv_avg_ms mv_min_ms mv_max_ms
      speedup_avg
      rows_baseline rows_mv
    ]

    Rails.logger.info("[validate_demo] Validating #{definitions.size} view(s), iterations=#{iterations}")
    CSV.open(out_csv, 'w') do |csv|
      csv << headers

      definitions.each do |defn|
        unless mv_names.include?(defn.name)
          Rails.logger.warn(%([validate_demo] Skipping "#{defn.name}" - not present in pg_matviews))
          next
        end

        begin
          result = MatViewsDemo::Validator.new(defn, iterations: iterations).run

          csv << [
            result[:view],
            result[:iterations],
            result[:baseline_avg_ms], result[:baseline_min_ms], result[:baseline_max_ms],
            result[:mv_avg_ms],       result[:mv_min_ms],       result[:mv_max_ms],
            result[:speedup_avg],
            result[:rows_baseline], result[:rows_mv]
          ]

          Rails.logger.info(
            "[validate_demo] #{result[:view]}: baseline_avg=#{result[:baseline_avg_ms]}ms, " \
            "mv_avg=#{result[:mv_avg_ms]}ms, speedup≈#{result[:speedup_avg]}x"
          )
        rescue StandardError => e
          Rails.logger.error(%([validate_demo] Error validating "#{defn.name}": #{e.class}: #{e.message}))
        end
      end
    end

    Rails.logger.info("[validate_demo] CSV written: #{out_csv}")
  end
end
