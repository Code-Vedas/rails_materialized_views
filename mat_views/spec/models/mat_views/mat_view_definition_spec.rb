# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

RSpec.describe MatViews::MatViewDefinition do
  subject(:model) { described_class.new(name: 'user_activity', sql: 'SELECT * FROM users') }

  it 'is valid with valid attributes' do
    expect(model).to be_valid
  end

  it 'requires a name' do
    model.name = nil
    expect(model).not_to be_valid
  end

  it 'requires a unique name' do
    described_class.create!(name: 'user_activity', sql: 'SELECT 1')
    expect(model).not_to be_valid
  end

  it 'requires SQL starting with SELECT' do
    model.sql = 'UPDATE users SET active = true'
    expect(model).not_to be_valid
  end

  it 'has many runs' do
    assoc = described_class.reflect_on_association(:mat_view_runs)
    expect(assoc.macro).to eq(:has_many)
    expect(assoc.options[:dependent]).to eq(:destroy)
  end

  describe 'refresh strategy' do
    it 'has a default refresh strategy' do
      expect(model.refresh_strategy).to eq('regular')
    end

    it 'allows setting a different refresh strategy' do
      model.refresh_strategy = 'concurrent'
      expect(model.refresh_strategy).to eq('concurrent')
    end

    it 'validates the refresh strategy' do
      expect { model.refresh_strategy = 'invalid' }.to raise_error(ArgumentError)
    end

    it 'has correct enum values' do
      expect(described_class.refresh_strategies).to eq({ 'regular' => 0, 'concurrent' => 1, 'swap' => 2 })
    end
  end

  describe 'last run' do
    let(:model) { described_class.create!(name: 'user_activity', sql: 'SELECT * FROM users') }

    it 'returns nil if there are no runs' do
      expect(model.last_run).to be_nil
    end

    it 'returns the most recent run' do
      model.mat_view_runs.create!(operation: 'create', status: 'success', started_at: 1.day.ago)
      recent_run = model.mat_view_runs.create!(operation: 'refresh', status: 'success', started_at: Time.current)
      expect(model.last_run).to eq(recent_run)
    end
  end

  describe 'scopes' do
    let!(:defn_one) { create(:mat_view_definition, name: 'A', schedule_cron: '0 0 *') }
    let!(:defn_two) { create(:mat_view_definition, name: 'B', refresh_strategy: :swap) }
    let!(:defn_three) { create(:mat_view_definition, name: 'C', schedule_cron: '30 1 *', unique_index_columns: [:id], refresh_strategy: :concurrent) }

    before do
      defn_one.mat_view_runs.create!(operation: 'create', status: 'success', started_at: '2025-01-01 10:00:00 UTC')
      defn_two.mat_view_runs.create!(operation: 'create', status: 'success', started_at: '2024-12-31 09:00:00 UTC')
    end

    describe 'ordered_by_name' do
      it 'orders ascending' do
        expect(described_class.ordered_by_name(:asc)).to eq([defn_one, defn_two, defn_three])
      end

      it 'orders descending' do
        expect(described_class.ordered_by_name(:desc)).to eq([defn_three, defn_two, defn_one])
      end
    end

    describe 'ordered_by_refresh_strategy' do
      it 'orders ascending' do
        expect(described_class.ordered_by_refresh_strategy(:asc)).to eq([defn_three, defn_one, defn_two])
      end

      it 'orders descending' do
        expect(described_class.ordered_by_refresh_strategy(:desc)).to eq([defn_two, defn_one, defn_three])
      end
    end

    describe 'ordered_by_schedule_cron' do
      it 'orders ascending with NULLS LAST' do
        expect(described_class.ordered_by_schedule_cron(:asc)).to eq([defn_one, defn_three, defn_two])
      end

      it 'orders descending with NULLS LAST' do
        expect(described_class.ordered_by_schedule_cron(:desc)).to eq([defn_three, defn_one, defn_two])
      end
    end

    describe 'ordered_by_last_run_at' do
      it 'orders ascending with NULLS LAST' do
        expect(described_class.ordered_by_last_run_at(:asc)).to eq([defn_one, defn_two, defn_three])
      end

      it 'orders descending with NULLS LAST' do
        expect(described_class.ordered_by_last_run_at(:desc)).to eq([defn_two, defn_one, defn_three])
      end
    end

    describe 'search_by_name' do
      it 'finds by partial match, case insensitive' do
        expect(described_class.search_by_name('a')).to eq([defn_one])
        expect(described_class.search_by_name('B')).to eq([defn_two])
        expect(described_class.search_by_name('z')).to be_empty
      end
    end

    describe 'search_by_refresh_strategy' do
      it 'finds by partial match, case insensitive on human labels' do
        expect(described_class.search_by_refresh_strategy('reg')).to eq([defn_one])
        expect(described_class.search_by_refresh_strategy('SWAP')).to eq([defn_two])
        expect(described_class.search_by_refresh_strategy('xyz')).to be_empty
      end
    end

    describe 'search_by_schedule_cron' do
      it 'finds by partial match, case insensitive' do
        expect(described_class.search_by_schedule_cron('0 0')).to eq([defn_one])
        expect(described_class.search_by_schedule_cron('30')).to eq([defn_three])
        expect(described_class.search_by_schedule_cron('xyz')).to be_empty
      end
    end

    describe 'search_by_last_run_at' do
      it 'finds by partial match, case insensitive on last run timestamp' do
        expect(described_class.search_by_last_run_at('2025-01-01')).to eq([defn_one])
        expect(described_class.search_by_last_run_at('2024-12-31')).to eq([defn_two])
        expect(described_class.search_by_last_run_at('xyz')).to be_empty
      end
    end

    describe 'filtered_by_name' do
      it 'filters by exact match' do
        expect(described_class.filtered_by_name('A')).to eq([defn_one])
        expect(described_class.filtered_by_name('B')).to eq([defn_two])
        expect(described_class.filtered_by_name('Z')).to be_empty
      end
    end

    describe 'filtered_by_refresh_strategy' do
      it 'filters by exact match' do
        expect(described_class.filtered_by_refresh_strategy('regular')).to eq([defn_one])
        expect(described_class.filtered_by_refresh_strategy('swap')).to eq([defn_two])
        expect(described_class.filtered_by_refresh_strategy('xyz')).to be_empty
      end
    end

    describe 'filtered_by_schedule_cron' do
      it 'filters by exact match' do
        expect(described_class.filtered_by_schedule_cron('0 0 *')).to eq([defn_one])
        expect(described_class.filtered_by_schedule_cron('30 1 *')).to eq([defn_three])
        expect(described_class.filtered_by_schedule_cron('xyz')).to be_empty
      end

      it 'filters by no value' do
        expect(described_class.filtered_by_schedule_cron('no_value')).to eq([defn_two])
      end
    end
  end

  describe 'select options for filters' do
    let!(:defn_one) { create(:mat_view_definition, name: 'A', schedule_cron: '0 0 *', refresh_strategy: :regular) }
    let!(:defn_two) { create(:mat_view_definition, name: 'B', refresh_strategy: :swap) }
    let!(:defn_three) { create(:mat_view_definition, name: 'C', schedule_cron: '30 1 *', refresh_strategy: :concurrent, unique_index_columns: [:id]) }

    before do
      defn_one.mat_view_runs.create!(operation: 'create', status: 'success', started_at: '2025-01-01 10:00:00 UTC')
      defn_two.mat_view_runs.create!(operation: 'create', status: 'success', started_at: '2024-12-31 09:00:00 UTC')
      defn_three.mat_view_runs.create!(operation: 'create', status: 'failed', started_at: '2024-12-30 08:00:00 UTC')
    end

    describe '.filter_options_for_name' do
      it 'returns unique names' do
        expect(described_class.filter_options_for_name).to eq([%w[A A], %w[B B], %w[C C]])
      end
    end

    describe '.filter_options_for_refresh_strategy' do
      it 'returns unique strategies in human-readable form' do
        expected_values = [%w[Regular regular], %w[Concurrent concurrent], %w[Swap swap]]
        expect(described_class.filter_options_for_refresh_strategy).to eq(expected_values)
      end
    end

    describe '.filter_options_for_schedule_cron' do
      it 'returns unique cron expressions including no value option' do
        expected_values = [['0 0 *', '0_0_*'], ['30 1 *', '30_1_*']]
        expect(described_class.filter_options_for_schedule_cron).to eq(expected_values)
      end
    end
  end
end
