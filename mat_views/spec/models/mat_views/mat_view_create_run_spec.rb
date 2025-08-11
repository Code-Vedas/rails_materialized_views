# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

RSpec.describe MatViews::MatViewCreateRun do
  let(:definition) { MatViews::MatViewDefinition.create!(name: 'sample', sql: 'SELECT 1') }

  it 'belongs to mat_view_definition' do
    assoc = described_class.reflect_on_association(:mat_view_definition)
    expect(assoc.macro).to eq(:belongs_to)
  end

  it "defaults to 'pending' status" do
    run = described_class.create!(mat_view_definition: definition)
    expect(run.status).to eq('pending')
  end

  it 'has the correct statuses' do
    expect(described_class.statuses.keys).to contain_exactly('pending', 'running', 'success', 'failed')
  end

  describe 'matrix of statuses [method]' do
    let(:matrix) do
      {
        pending: %w[running success failed],
        running: %w[pending success failed],
        success: %w[pending running failed],
        failed: %w[pending running success]
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
        0 => [1, 2, 3], # pending
        1 => [0, 2, 3], # running
        2 => [0, 1, 3], # success
        3 => [0, 1, 2]  # failed
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
end
