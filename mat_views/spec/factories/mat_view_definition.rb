# frozen_string_literal: true

FactoryBot.define do
  factory :mat_view_definition, class: 'MatViews::MatViewDefinition' do
    sequence(:name) { |n| "mv_example_#{n}" }
    sql { 'SELECT id FROM users' }
    refresh_strategy { :regular } # enum: { regular: 0, concurrent: 1, swap: 2 }
    unique_index_columns { [] }   # set to %w[id] for concurrent strategy tests
    schedule_cron { nil }
  end
end
