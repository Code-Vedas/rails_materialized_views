# frozen_string_literal: true

FactoryBot.define do
  factory :mat_view_refresh_run, class: 'MatViews::MatViewRefreshRun' do
    mat_view_definition factory: :mat_view_definition
    status      { :pending }
    started_at  { Time.current }
    finished_at { nil }
    duration_ms { nil }
    rows_count  { nil }
    error       { nil }
    meta        { {} }
  end
end
