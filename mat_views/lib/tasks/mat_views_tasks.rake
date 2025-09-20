# frozen_string_literal: true

require 'rake'
require_relative 'helpers'

# rubocop:disable Metrics/BlockLength
namespace :mat_views do
  helpers = MatViews::Tasks::Helpers

  # ───────────── CREATE ─────────────

  desc 'Enqueue a CREATE for a specific view by its name (optionally schema-qualified)'
  task :create_by_name, %i[view_name force row_count_strategy yes] => :environment do |_t, args|
    rcs   = helpers.parse_row_count_strategy(args[:row_count_strategy])
    force = helpers.parse_force?(args[:force])
    skip  = helpers.skip_confirm?(args[:yes])
    defn  = helpers.find_definition_by_name!(args[:view_name])

    helpers.confirm!("Enqueue CREATE for view=#{defn.name} (id=#{defn.id}), force=#{force}, row_count_strategy=#{rcs}", skip: skip)
    helpers.enqueue_create(defn.id, force, rcs)
    helpers.logger.info("[mat_views] Enqueued CreateViewJob for definition ##{defn.id} (#{defn.name}), force=#{force}, row_count_strategy=#{rcs}.")
  end

  desc 'Enqueue a CREATE for a specific view by its definition ID'
  task :create_by_id, %i[mat_view_definition_id force row_count_strategy yes] => :environment do |_t, args|
    raise 'mat_views:create_by_id requires a mat_view_definition_id parameter' if args[:mat_view_definition_id].to_s.strip.empty?

    rcs   = helpers.parse_row_count_strategy(args[:row_count_strategy])
    force = helpers.parse_force?(args[:force])
    skip  = helpers.skip_confirm?(args[:yes])

    defn = MatViews::MatViewDefinition.find_by(id: args[:mat_view_definition_id])
    raise "No MatViews::MatViewDefinition found for id=#{args[:mat_view_definition_id]}" unless defn

    helpers.confirm!("Enqueue CREATE for id=#{defn.id} (#{defn.name}), force=#{force}, row_count_strategy=#{rcs}", skip: skip)
    helpers.enqueue_create(defn.id, force, rcs)
    helpers.logger.info("[mat_views] Enqueued CreateViewJob for definition ##{defn.id} (#{defn.name}), force=#{force}, row_count_strategy=#{rcs}.")
  end

  desc 'Enqueue CREATE jobs for ALL defined materialised views'
  task :create_all, %i[force row_count_strategy yes] => :environment do |_t, args|
    rcs   = helpers.parse_row_count_strategy(args[:row_count_strategy])
    force = helpers.parse_force?(args[:force])
    skip  = helpers.skip_confirm?(args[:yes])

    scope = MatViews::MatViewDefinition.all
    count = scope.count
    if count.zero?
      helpers.logger.info('[mat_views] No mat view definitions found.')
      next
    end

    helpers.confirm!("Enqueue CREATE for ALL (#{count}) views, force=#{force}, row_count_strategy=#{rcs}", skip: skip)
    scope.find_each { |defn| helpers.enqueue_create(defn.id, force, rcs) }
    helpers.logger.info("[mat_views] Enqueued #{count} CreateViewJob(s), force=#{force}, row_count_strategy=#{rcs}.")
  end

  # ───────────── REFRESH ─────────────

  desc 'Enqueue a REFRESH for a specific view by its name (optionally schema-qualified)'
  task :refresh_by_name, %i[view_name row_count_strategy yes] => :environment do |_t, args|
    rcs  = helpers.parse_row_count_strategy(args[:row_count_strategy])
    skip = helpers.skip_confirm?(args[:yes])
    defn = helpers.find_definition_by_name!(args[:view_name])

    helpers.confirm!("Enqueue REFRESH for view=#{defn.name} (id=#{defn.id}), row_count_strategy=#{rcs}", skip: skip)
    helpers.enqueue_refresh(defn.id, rcs)
    helpers.logger.info("[mat_views] Enqueued RefreshViewJob for definition ##{defn.id} (#{defn.name}), row_count_strategy=#{rcs}.")
  end

  desc 'Enqueue a REFRESH for a specific view by its definition ID'
  task :refresh_by_id, %i[mat_view_definition_id row_count_strategy yes] => :environment do |_t, args|
    raise 'mat_views:refresh_by_id requires a mat_view_definition_id parameter' if args[:mat_view_definition_id].to_s.strip.empty?

    rcs  = helpers.parse_row_count_strategy(args[:row_count_strategy])
    skip = helpers.skip_confirm?(args[:yes])

    defn = MatViews::MatViewDefinition.find_by(id: args[:mat_view_definition_id])
    raise "No MatViews::MatViewDefinition found for id=#{args[:mat_view_definition_id]}" unless defn

    helpers.confirm!("Enqueue REFRESH for id=#{defn.id} (#{defn.name}), row_count_strategy=#{rcs}", skip: skip)
    helpers.enqueue_refresh(defn.id, rcs)
    helpers.logger.info("[mat_views] Enqueued RefreshViewJob for definition ##{defn.id} (#{defn.name}), row_count_strategy=#{rcs}.")
  end

  desc 'Enqueue REFRESH jobs for ALL defined materialised views'
  task :refresh_all, %i[row_count_strategy yes] => :environment do |_t, args|
    rcs  = helpers.parse_row_count_strategy(args[:row_count_strategy])
    skip = helpers.skip_confirm?(args[:yes])

    scope = MatViews::MatViewDefinition.all
    count = scope.count
    if count.zero?
      helpers.logger.info('[mat_views] No mat view definitions found.')
      next
    end

    helpers.confirm!("Enqueue REFRESH for ALL (#{count}) views, row_count_strategy=#{rcs}", skip: skip)
    scope.find_each { |defn| helpers.enqueue_refresh(defn.id, rcs) }
    helpers.logger.info("[mat_views] Enqueued #{count} RefreshViewJob(s), row_count_strategy=#{rcs}.")
  end

  # ───────────── DELETE ─────────────

  desc 'Enqueue a DELETE (DROP MATERIALIZED VIEW) for a specific view by its name (optionally schema-qualified)'
  task :delete_by_name, %i[view_name cascade row_count_strategy yes] => :environment do |_t, args|
    cascade = helpers.parse_cascade?(args[:cascade])
    rcs     = helpers.parse_row_count_strategy(args[:row_count_strategy])
    skip    = helpers.skip_confirm?(args[:yes])
    defn    = helpers.find_definition_by_name!(args[:view_name])

    helpers.confirm!("Enqueue DELETE for view=#{defn.name} (id=#{defn.id}), cascade=#{cascade}, row_count_strategy=#{rcs}", skip: skip)
    helpers.enqueue_delete(defn.id, cascade, rcs)
    helpers.logger.info("[mat_views] Enqueued DeleteViewJob for definition ##{defn.id} (#{defn.name}), cascade=#{cascade}, row_count_strategy=#{rcs}.")
  end

  desc 'Enqueue a DELETE (DROP MATERIALIZED VIEW) for a specific view by its definition ID'
  task :delete_by_id, %i[mat_view_definition_id cascade row_count_strategy yes] => :environment do |_t, args|
    raise 'mat_views:delete_by_id requires a mat_view_definition_id parameter' if args[:mat_view_definition_id].to_s.strip.empty?

    rcs     = helpers.parse_row_count_strategy(args[:row_count_strategy])
    cascade = helpers.parse_cascade?(args[:cascade])
    skip    = helpers.skip_confirm?(args[:yes])

    defn = MatViews::MatViewDefinition.find_by(id: args[:mat_view_definition_id])
    raise "No MatViews::MatViewDefinition found for id=#{args[:mat_view_definition_id]}" unless defn

    helpers.confirm!("Enqueue DELETE for id=#{defn.id} (#{defn.name}), cascade=#{cascade}, row_count_strategy=#{rcs}", skip: skip)
    helpers.enqueue_delete(defn.id, cascade, rcs)
    helpers.logger.info("[mat_views] Enqueued DeleteViewJob for definition ##{defn.id} (#{defn.name}), cascade=#{cascade}, row_count_strategy=#{rcs}.")
  end

  desc 'Enqueue DELETE jobs for ALL defined materialised views'
  task :delete_all, %i[cascade row_count_strategy yes] => :environment do |_t, args|
    rcs     = helpers.parse_row_count_strategy(args[:row_count_strategy])
    cascade = helpers.parse_cascade?(args[:cascade])
    skip    = helpers.skip_confirm?(args[:yes])

    scope = MatViews::MatViewDefinition.all
    count = scope.count
    if count.zero?
      helpers.logger.info('[mat_views] No mat view definitions found.')
      next
    end

    helpers.confirm!("Enqueue DELETE for ALL (#{count}) views, cascade=#{cascade}, row_count_strategy=#{rcs}", skip: skip)
    scope.find_each { |defn| helpers.enqueue_delete(defn.id, cascade, rcs) }
    helpers.logger.info("[mat_views] Enqueued #{count} DeleteViewJob(s), cascade=#{cascade}, row_count_strategy=#{rcs}.")
  end
end
# rubocop:enable Metrics/BlockLength
