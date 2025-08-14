# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

require 'securerandom'

PLANS  = %w[free pro enterprise].freeze
EVENTS = %w[click signup login].freeze

namespace :mat_views do
  # --- SEED -----------------------------------------------------------
  desc 'Load demo datasets (usage: rake mat_views:seed_demo[scale,--yes])'
  task :seed_demo, %i[scale yes] => :environment do |_t, args|
    scale = (args[:scale] || ENV['SCALE'] || 1).to_i
    skip  = %w[--yes yes y 1].include?((args[:yes] || ENV['YES'] || '').to_s.downcase)

    Rails.logger.info("[demo] Seed demo about to run: scale=#{scale}")
    unless skip
      $stdout.print('Proceed? [y/N]: ')
      $stdout.flush
      ans = $stdin.gets&.strip&.downcase
      raise 'Aborted.' unless ans&.start_with?('y')
    end

    require 'faker'

    # wipe
    Account.delete_all
    Event.delete_all
    Session.delete_all
    User.delete_all

    ActiveRecord::Base.connection.reset_pk_sequence!('users')
    ActiveRecord::Base.connection.reset_pk_sequence!('accounts')
    ActiveRecord::Base.connection.reset_pk_sequence!('events')
    ActiveRecord::Base.connection.reset_pk_sequence!('sessions')

    now = Time.current
    users = []
    (500 * [scale, 1].max).times do
      users << { name: Faker::Name.name, email: Faker::Internet.unique.email, created_at: now, updated_at: now }
    end
    User.insert_all(users) if users.any?

    user_ids = User.pluck(:id)
    accounts = []
    events = []
    sessions = []

    user_ids.each do |uid|
      rand(1..2).times do
        accounts << { user_id: uid, plan: PLANS.sample, status: 'active', created_at: now, updated_at: now }
      end
      rand(10..30).times do
        events << {
          user_id: uid,
          event_type: EVENTS.sample,
          occurred_at: Faker::Time.backward(days: 30),
          properties: { ref: Faker::Internet.domain_name },
          created_at: now, updated_at: now
        }
      end
      rand(1..5).times do
        started_at = Faker::Time.backward(days: 7)
        ended_at   = started_at + rand((5 * 60)..(8 * 60 * 60))
        sessions << {
          user_id: uid, session_token: SecureRandom.hex(10),
          started_at: started_at, ended_at: ended_at, created_at: now, updated_at: now
        }
      end
    end

    Account.insert_all(accounts) if accounts.any?
    Event.insert_all(events)     if events.any?
    Session.insert_all(sessions) if sessions.any?

    Rails.logger.info("[demo] Seeded: users=#{users.size} accounts=#{accounts.size} events=#{events.size} sessions=#{sessions.size}")

    # helpful base indexes
    conn = ActiveRecord::Base.connection
    conn.execute('CREATE INDEX IF NOT EXISTS index_events_on_occurred_at ON events(occurred_at)')
    conn.execute('CREATE INDEX IF NOT EXISTS index_sessions_on_started_at ON sessions(started_at)')
    conn.execute('CREATE INDEX IF NOT EXISTS index_accounts_on_plan ON accounts(plan)')
    Rails.logger.info('[demo] Base indexes ensured.')
  end

  # --- DEFINE DEMO VIEW DEFINITIONS ----------------------------------
  desc 'Define 4 demo mat view definitions (idempotent)'
  task :define_demo_views, [] => :environment do
    defs = []

    defs << MatViews::MatViewDefinition.where(name: 'mv_users').first_or_initialize.tap do |d|
      d.sql = <<~SQL.squish
        SELECT u.id, u.name, u.email, u.created_at
        FROM users u
      SQL
      d.refresh_strategy = :concurrent
      d.unique_index_columns = ['id']
      d.save! if d.changed?
    end

    defs << MatViews::MatViewDefinition.where(name: 'mv_user_accounts').first_or_initialize.tap do |d|
      d.sql = <<~SQL.squish
        SELECT u.id AS user_id, COUNT(a.*) AS accounts_count
        FROM users u
        LEFT JOIN accounts a ON a.user_id = u.id
        GROUP BY u.id
      SQL
      d.refresh_strategy = :concurrent
      d.unique_index_columns = ['user_id']
      d.save! if d.changed?
    end

    defs << MatViews::MatViewDefinition.where(name: 'mv_user_accounts_events').first_or_initialize.tap do |d|
      d.sql = <<~SQL.squish
        SELECT u.id AS user_id,
               COUNT(a.*) AS accounts_count,
               COUNT(e.*) AS events_count
        FROM users u
        LEFT JOIN accounts a ON a.user_id = u.id
        LEFT JOIN events   e ON e.user_id = u.id
        GROUP BY u.id
      SQL
      d.refresh_strategy = :concurrent
      d.unique_index_columns = ['user_id']
      d.save! if d.changed?
    end

    defs << MatViews::MatViewDefinition.where(name: 'mv_user_activity').first_or_initialize.tap do |d|
      d.sql = <<~SQL.squish
        SELECT u.id AS user_id,
               COUNT(a.*) AS accounts_count,
               COUNT(e.*) AS events_count,
               COUNT(s.*) AS sessions_count
        FROM users u
        LEFT JOIN accounts a ON a.user_id = u.id
        LEFT JOIN events   e ON e.user_id = u.id
        LEFT JOIN sessions s ON s.user_id = u.id
        GROUP BY u.id
      SQL
      d.refresh_strategy = :concurrent
      d.unique_index_columns = ['user_id']
      d.save! if d.changed?
    end

    Rails.logger.info("[demo] Defined/updated #{defs.size} MatViews::MatViewDefinition records.")
  end

  # --- BOOTSTRAP: seed + define + create + unique indexes + refresh ---
  desc 'Full bootstrap: seed, define demo views, create & index them, refresh'
  task :bootstrap_demo, %i[scale yes] => :environment do |_t, args|
    Rake::Task['mat_views:seed_demo'].invoke(args[:scale], args[:yes])
    Rake::Task['mat_views:define_demo_views'].invoke

    # Create MVs via the gem’s tasks (skip confirms)
    Rake::Task['mat_views:create_all'].reenable
    Rake::Task['mat_views:create_all'].invoke(nil, '--yes')

    conn = ActiveRecord::Base.connection
    conn.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_users_id_uniq ON mv_users(id)')
    conn.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_user_accounts_user_id_uniq ON mv_user_accounts(user_id)')
    conn.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_user_accounts_events_user_id_uniq ON mv_user_accounts_events(user_id)')
    conn.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_user_activity_user_id_uniq ON mv_user_activity(user_id)')
    Rails.logger.info('[demo] MV unique indexes ensured.')

    # Refresh (estimated default)
    Rake::Task['mat_views:refresh_all'].reenable
    Rake::Task['mat_views:refresh_all'].invoke(nil, '--yes')
    Rails.logger.info('[demo] Demo bootstrap complete.')
  end
end
