# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

RSpec.describe MatViews do
  it 'defines the MatViews module' do
    expect(defined?(MatViews)).to eq('constant') # rubocop:disable RSpec/DescribedClass
  end

  it 'has a version number' do
    expect(MatViews::VERSION).not_to be_nil
  end
end
