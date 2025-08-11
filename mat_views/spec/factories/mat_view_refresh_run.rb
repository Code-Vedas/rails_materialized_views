# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

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
