# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

RSpec.describe 'smriti.gemspec' do # rubocop:disable RSpec/DescribeClass
  subject(:spec) { Gem::Specification.load('smriti.gemspec') }

  it 'has mat_view name' do
    expect(spec.name).to eq('smriti')
  end

  it 'has mat_view version' do
    expect(spec.version).to eq(Smriti::VERSION)
  end
end
