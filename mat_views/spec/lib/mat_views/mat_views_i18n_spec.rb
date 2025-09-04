# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

RSpec.describe MatViewsI18n do
  subject(:model_class) { MatViews::MatViewDefinition }

  describe '.human_name' do
    it 'returns the translated attribute name when available' do
      expect(model_class.human_name(:name)).to eq('Name')
    end

    it 'falls back to humanized attribute when missing' do
      expect(model_class.human_name(:unknown_attribute)).to eq('Unknown attribute')
    end
  end

  describe '.human_enum_name' do
    it 'returns the translated enum value when available' do
      expect(model_class.human_enum_name(:refresh_strategy, :regular)).to eq('Regular')
      expect(model_class.human_enum_name(:refresh_strategy, 'concurrent')).to eq('Concurrent')
    end

    it 'falls back to humanized value when translation is missing' do
      expect(model_class.human_enum_name(:refresh_strategy, :nonexistent)).to eq('Nonexistent')
    end
  end

  describe '.human_enum_options' do
    it 'returns an array of [label, value] for each enum key' do
      opts = model_class.human_enum_options(:refresh_strategy)

      expect(opts).to contain_exactly(%w[Regular regular], %w[Concurrent concurrent], %w[Swap swap])
    end
  end

  describe '.placeholder_for' do
    it 'returns the translated placeholder when present' do
      expect(model_class.placeholder_for(:name)).to eq('Enter name')
    end

    it 'returns empty string when translation is missing' do
      expect(model_class.placeholder_for(:missing)).to eq('')
    end
  end

  describe '.hint_for' do
    it 'returns the translated hint when present' do
      expect(model_class.hint_for(:sql)).to eq('The SQL query must be a valid SELECT statement.')
    end

    it 'returns empty string when translation is missing' do
      expect(model_class.hint_for(:missing)).to eq('')
    end
  end
end
