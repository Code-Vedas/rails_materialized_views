# frozen_string_literal: true

puts 'Seeding Users, Accounts, Events, Sessions...'

Account.delete_all
Event.delete_all
Session.delete_all
User.delete_all

ActiveRecord::Base.connection.reset_pk_sequence!('users')
ActiveRecord::Base.connection.reset_pk_sequence!('accounts')
ActiveRecord::Base.connection.reset_pk_sequence!('events')
ActiveRecord::Base.connection.reset_pk_sequence!('sessions')

# %w[free pro enterprise]
PLANS = %w[free pro enterprise].freeze
EVENTS = %w[click signup login].freeze

ActiveRecord::Base.transaction do
  now = Time.current

  users = []
  500.times do
    users << {
      name: Faker::Name.name,
      email: Faker::Internet.unique.email,
      created_at: now,
      updated_at: now
    }
  end
  User.insert_all(users)

  user_ids = User.pluck(:id)

  accounts = []
  events = []
  sessions = []

  user_ids.each do |uid|
    rand(1..2).times do
      accounts << {
        user_id: uid,
        plan: PLANS.sample,
        status: 'active',
        created_at: now,
        updated_at: now
      }
    end

    rand(10..30).times do
      events << {
        user_id: uid,
        event_type: EVENTS.sample,
        occurred_at: Faker::Time.backward(days: 30),
        properties: { ref: Faker::Internet.domain_name },
        created_at: now,
        updated_at: now
      }
    end

    rand(1..5).times do
      started_at = Faker::Time.backward(days: 7)
      duration = rand((5 * 60)..(8 * 60 * 60))
      ended_at = started_at + duration
      sessions << {
        user_id: uid,
        session_token: SecureRandom.hex(10),
        started_at: started_at,
        ended_at: ended_at,
        created_at: now,
        updated_at: now
      }
    end
  end

  Account.insert_all(accounts)
  Event.insert_all(events)
  Session.insert_all(sessions)
end

puts '✅ Done seeding.'
