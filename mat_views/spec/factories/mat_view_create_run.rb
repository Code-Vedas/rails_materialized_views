# frozen_string_literal: true

FactoryBot.define do
  factory :mat_view_create_run, class: 'MatViews::MatViewCreateRun' do
    mat_view_definition factory: :mat_view_definition
    status      { :pending }
    started_at  { Time.current }
    finished_at { nil }
    duration_ms { nil }
    error       { nil }
    meta        { {} }
  end
end
