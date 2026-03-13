# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

RSpec.describe 'Factory sanity' do # rubocop:disable RSpec/DescribeClass
  let(:defn) { create(:mat_view_definition) }
  let(:run) { create(:mat_view_run, status: :running, operation: :refresh) }

  it 'builds and creates mat_view_definition' do
    expect(defn).to be_persisted
    expect(defn.refresh_strategy).to eq('regular')
    expect(defn.sql).to start_with('SELECT')
  end

  it 'builds and creates mat_view_run' do
    expect(run).to be_persisted
    expect(run.status).to eq('running')
    expect(run.operation).to eq('refresh')
    expect(run.mat_view_definition_id).not_to be_nil
  end
end
