# frozen_string_literal: true

RSpec.describe 'Factory sanity' do # rubocop:disable RSpec/DescribeClass
  let(:defn) { create(:mat_view_definition) }
  let(:run) { create(:mat_view_refresh_run, mat_view_definition: defn, status: :pending) }

  it 'builds and creates mat_view_definition' do
    expect(defn).to be_persisted
    expect(defn.refresh_strategy).to eq('regular')
    expect(defn.sql).to start_with('SELECT')
  end

  it 'builds and creates mat_view_refresh_run' do
    expect(run).to be_persisted
    expect(run.status).to eq('pending')
    expect(run.mat_view_definition_id).to eq(defn.id)
  end
end
