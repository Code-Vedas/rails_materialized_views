# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

RSpec.describe MatViews::MatViewRun do
  let(:definition) { MatViews::MatViewDefinition.create!(name: 'sample', sql: 'SELECT 1') }

  it 'belongs to mat_view_definition' do
    assoc = described_class.reflect_on_association(:mat_view_definition)
    expect(assoc.macro).to eq(:belongs_to)
  end

  it "defaults to 'running' status" do
    run = described_class.create!(mat_view_definition: definition)
    expect(run.status).to eq('running')
  end

  it 'has the correct statuses' do
    expect(described_class.statuses.keys).to contain_exactly('running', 'success', 'failed')
  end

  it 'has the correct operations' do
    expect(described_class.operations.keys).to contain_exactly('create', 'refresh', 'drop')
  end

  describe 'matrix of statuses [method]' do
    let(:matrix) do
      {
        running: %w[success failed],
        success: %w[running failed],
        failed: %w[running success]
      }
    end

    it 'validates status transitions' do
      matrix.each do |from_status, to_statuses|
        to_statuses.each do |to_status|
          run = described_class.create!(mat_view_definition: definition, status: from_status)
          run.send("status_#{to_status}!")
          expect(run.status).to eq(to_status)
        end
      end
    end
  end

  describe 'matrix of statuses [by integer]' do
    let(:matrix) do
      {
        0 => [1, 2], # running
        1 => [0, 2], # success
        2 => [0, 1]  # failed
      }
    end

    it 'validates status transitions by integer' do
      matrix.each do |from_status, to_statuses|
        to_statuses.each do |to_status|
          run = described_class.create!(mat_view_definition: definition, status: from_status)
          run.update(status: to_status)
          expect(run.status).to eq(described_class.statuses.key(to_status))
        end
      end
    end
  end

  describe 'scopes' do
    it 'returns create runs' do
      create_run = described_class.create!(mat_view_definition: definition, operation: :create)
      expect(described_class.create_runs).to include(create_run)
    end

    it 'returns refresh runs' do
      refresh_run = described_class.create!(mat_view_definition: definition, operation: :refresh)
      expect(described_class.refresh_runs).to include(refresh_run)
    end

    it 'returns drop runs' do
      drop_run = described_class.create!(mat_view_definition: definition, operation: :drop)
      expect(described_class.drop_runs).to include(drop_run)
    end
  end

  describe '#row_count_before' do
    it 'allows setting and getting row count' do
      run = described_class.create!(mat_view_definition: definition, meta: { response: { row_count_before: 100 } })
      expect(run.row_count_before).to eq(100)
    end

    it 'returns nil if row count is not set' do
      run = described_class.create!(mat_view_definition: definition)
      expect(run.row_count_before).to be_nil
    end
  end

  describe '#row_count_after' do
    it 'allows setting and getting row count' do
      run = described_class.create!(mat_view_definition: definition, meta: { response: { row_count_after: 200 } })
      expect(run.row_count_after).to eq(200)
    end

    it 'returns nil if row count is not set' do
      run = described_class.create!(mat_view_definition: definition)
      expect(run.row_count_after).to be_nil
    end
  end
end
