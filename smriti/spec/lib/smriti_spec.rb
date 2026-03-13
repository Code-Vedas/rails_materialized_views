# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

RSpec.describe Smriti do
  it 'defines the Smriti module' do
    expect(defined?(Smriti)).to eq('constant') # rubocop:disable RSpec/DescribedClass
  end

  it 'has a version number' do
    expect(Smriti::VERSION).not_to be_nil
  end

  it 'has the correct version number' do
    expect(Smriti::VERSION).to eq('0.4.0')
  end
end
