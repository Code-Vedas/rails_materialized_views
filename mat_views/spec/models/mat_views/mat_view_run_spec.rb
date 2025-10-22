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
    let(:definition_a) { MatViews::MatViewDefinition.create!(name: 'a_view', sql: 'SELECT 1') }
    let(:definition_b) { MatViews::MatViewDefinition.create!(name: 'b_view', sql: 'SELECT 1') }
    let!(:create_run) do
      described_class.create!(mat_view_definition: definition_a,
                              operation: :create,
                              status: :success,
                              duration_ms: 150,
                              started_at: '2025-01-01 10:00:00 UTC')
    end
    let!(:refresh_run) do
      described_class.create!(mat_view_definition: definition_a,
                              operation: :refresh,
                              status: :running,
                              duration_ms: 30,
                              started_at: '2024-12-31 09:00:00 UTC')
    end
    let!(:drop_run) do
      described_class.create!(mat_view_definition: definition_b,
                              status: :failed,
                              meta: { response: { error: 'Some error' } },
                              operation: :drop)
    end

    it 'returns create runs' do
      expect(described_class.create_runs).to include(create_run)
    end

    it 'returns refresh runs' do
      expect(described_class.refresh_runs).to include(refresh_run)
    end

    it 'returns drop runs' do
      expect(described_class.drop_runs).to include(drop_run)
    end

    describe 'ordered_by_operation' do
      it 'orders ascending' do
        expect(described_class.ordered_by_operation(:asc)).to eq([create_run, drop_run, refresh_run])
      end

      it 'orders descending' do
        expect(described_class.ordered_by_operation(:desc)).to eq([refresh_run, drop_run, create_run])
      end
    end

    describe 'ordered_by_definition' do
      it 'orders ascending' do
        expect(described_class.ordered_by_definition(:asc).last).to eq(drop_run)
      end

      it 'orders descending' do
        expect(described_class.ordered_by_definition(:desc).first).to eq(drop_run)
      end
    end

    describe 'ordered_by_started_at' do
      it 'orders ascending' do
        expect(described_class.ordered_by_started_at(:asc)).to eq([refresh_run, create_run, drop_run])
      end

      it 'orders descending' do
        expect(described_class.ordered_by_started_at(:desc)).to eq([drop_run, create_run, refresh_run])
      end
    end

    describe 'ordered_by_status' do
      it 'orders ascending' do
        expect(described_class.ordered_by_status(:asc)).to eq([drop_run, refresh_run, create_run])
      end

      it 'orders descending' do
        expect(described_class.ordered_by_status(:desc)).to eq([create_run, refresh_run, drop_run])
      end
    end

    describe 'ordered_by_duration_ms' do
      it 'orders ascending' do
        expect(described_class.ordered_by_duration_ms(:asc)).to eq([refresh_run, create_run, drop_run])
      end

      it 'orders descending' do
        expect(described_class.ordered_by_duration_ms(:desc)).to eq([drop_run, create_run, refresh_run])
      end
    end

    describe 'search_by_operation' do
      it 'finds by partial match, case insensitive on human labels' do
        expect(described_class.search_by_operation('cre')).to eq([create_run])
        expect(described_class.search_by_operation('REFRESH')).to eq([refresh_run])
        expect(described_class.search_by_operation('xyz')).to be_empty
      end
    end

    describe 'search_by_definition' do
      it 'finds by partial match, case insensitive' do
        expect(described_class.search_by_definition('a_')).to contain_exactly(create_run, refresh_run)
        expect(described_class.search_by_definition('B_')).to eq([drop_run])
        expect(described_class.search_by_definition('z')).to be_empty
      end
    end

    describe 'search_by_status' do
      it 'finds by partial match, case insensitive on human labels' do
        expect(described_class.search_by_status('suc')).to eq([create_run])
        expect(described_class.search_by_status('FAILED')).to eq([drop_run])
        expect(described_class.search_by_status('xyz')).to be_empty
      end
    end

    describe 'search_by_duration_ms' do
      it 'finds by exact match' do
        expect(described_class.search_by_duration_ms('150')).to eq([create_run])
        expect(described_class.search_by_duration_ms('30')).to eq([refresh_run])
        expect(described_class.search_by_duration_ms('999')).to be_empty
      end
    end

    describe 'filtered_by_operation' do
      it 'filters by exact match' do
        expect(described_class.filtered_by_operation('create')).to eq([create_run])
        expect(described_class.filtered_by_operation('refresh')).to eq([refresh_run])
        expect(described_class.filtered_by_operation('drop')).to eq([drop_run])
        expect(described_class.filtered_by_operation('xyz')).to be_empty
      end
    end

    describe 'filtered_by_definition' do
      it 'filters by exact match' do
        expect(described_class.filtered_by_definition(definition_a.id)).to eq([create_run, refresh_run])
        expect(described_class.filtered_by_definition(definition_b.id.to_s)).to eq([drop_run])
        expect(described_class.filtered_by_definition('z_view')).to be_empty
      end
    end

    describe 'filtered_by_status' do
      it 'filters by exact match' do
        expect(described_class.filtered_by_status('running')).to eq([refresh_run])
        expect(described_class.filtered_by_status('success')).to eq([create_run])
        expect(described_class.filtered_by_status('failed')).to eq([drop_run])
        expect(described_class.filtered_by_status('xyz')).to be_empty
      end
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

  describe 'select options for filters' do
    let(:definition_a) { MatViews::MatViewDefinition.create!(name: 'a_view', sql: 'SELECT 1') }
    let(:definition_b) { MatViews::MatViewDefinition.create!(name: 'b_view', sql: 'SELECT 1') }

    before do
      described_class.create!(mat_view_definition: definition_a,
                              operation: :create,
                              status: :success,
                              duration_ms: 150,
                              started_at: '2025-01-01 10:00:00 UTC')
      described_class.create!(mat_view_definition: definition_a,
                              operation: :refresh,
                              status: :running,
                              duration_ms: 30,
                              started_at: '2024-12-31 09:00:00 UTC')
      described_class.create!(mat_view_definition: definition_b,
                              status: :failed,
                              meta: { response: { error: 'Some error' } },
                              operation: :drop)
    end

    describe 'filter_options_for_operation' do
      it 'returns unique operations with human labels' do
        options = described_class.filter_options_for_operation
        expect(options).to contain_exactly(
          %w[Create create],
          %w[Refresh refresh],
          %w[Drop drop]
        )
      end
    end

    describe 'filter_options_for_definition' do
      it 'returns unique definitions with names and ids' do
        options = described_class.filter_options_for_definition
        expect(options).to contain_exactly(
          ['a_view', definition_a.id],
          ['b_view', definition_b.id]
        )
      end
    end

    describe 'filter_options_for_status' do
      it 'returns unique statuses with human labels' do
        options = described_class.filter_options_for_status
        expect(options).to contain_exactly(
          %w[Running running],
          %w[Success success],
          %w[Failed failed]
        )
      end
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

  describe '#error_message' do
    let(:error_msg) { 'Materialized view refresh failed due to timeout' }

    it 'returns the error message if present in meta' do
      run = described_class.create!(mat_view_definition: definition, meta: { error: { message: error_msg } })
      expect(run.error_message).to eq(error_msg)
    end
  end
end
