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

  it 'has many refresh runs' do
    assoc = described_class.reflect_on_association(:mat_view_refresh_runs)
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
end
