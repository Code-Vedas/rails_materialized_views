# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

RSpec.describe MatViews::Engine do
  it 'inherits from Rails::Engine' do
    expect(described_class < Rails::Engine).to be(true)
  end

  it 'isolates the MatViews namespace' do
    expect(described_class.isolated).to be(true)
  end
end
