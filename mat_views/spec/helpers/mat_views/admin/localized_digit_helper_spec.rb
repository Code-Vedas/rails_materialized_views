# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

RSpec.describe MatViews::Admin::LocalizedDigitHelper, type: :helper do
  # 0→a, 1→b, ..., 9→j
  let(:letters_map) do
    {
      zero: 'a', one: 'b', two: 'c', three: 'd', four: 'e',
      five: 'f', six: 'g', seven: 'h', eight: 'i', nine: 'j'
    }
  end

  before do
    allow(I18n).to receive(:t).with('numbers', default: nil).and_return(letters_map)
  end

  describe '#localized_numbers' do
    it 'returns ASCII letter mappings for digits' do
      result = helper.send(:localized_numbers)
      expect(result).to eq({
                             '0' => 'a', '1' => 'b', '2' => 'c', '3' => 'd', '4' => 'e',
                             '5' => 'f', '6' => 'g', '7' => 'h', '8' => 'i', '9' => 'j'
                           })
      expect(result.values.all?(&:ascii_only?)).to be(true)
    end
  end

  describe '#localized_digits' do
    it 'replaces digits in a string using the letter mapping' do
      expect(helper.send(:localized_digits, 'Version 2.5')).to eq('Version c.f') # 2→c, 5→f
    end

    it 'converts numeric input' do
      expect(helper.send(:localized_digits, 2025)).to eq('cacf') # 2→c,0→a,2→c,5→f
    end

    it 'leaves strings without digits unchanged' do
      expect(helper.send(:localized_digits, 'No numbers here')).to eq('No numbers here')
    end
  end

  describe '#l_with_digits' do
    before { allow(I18n).to receive(:l).and_return('2025-10-10') }

    it 'localizes digits in formatted output' do
      date = Date.new(2025, 10, 10)
      expect(helper.send(:l_with_digits, date)).to eq('cacf-ba-ba') # 2025→cacf, 10→ba
    end

    it 'passes kwargs to I18n.l' do
      now = Time.zone.now
      helper.send(:l_with_digits, now, format: :short)
      expect(I18n).to have_received(:l).with(now, format: :short)
    end
  end
end
