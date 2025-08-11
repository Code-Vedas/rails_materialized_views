# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

RSpec.describe 'mat_views.gemspec' do # rubocop:disable RSpec/DescribeClass
  subject(:spec) { Gem::Specification.load('mat_views.gemspec') }

  it 'has mat_view name' do
    expect(spec.name).to eq('mat_views')
  end

  it 'has mat_view version' do
    expect(spec.version).to eq(MatViews::VERSION)
  end
end
