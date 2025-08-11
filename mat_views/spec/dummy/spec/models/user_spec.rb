# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

RSpec.describe User, type: :model do
  it { is_expected.to have_many(:accounts).dependent(:destroy) }
  it { is_expected.to have_many(:events).dependent(:destroy) }
  it { is_expected.to have_many(:sessions).dependent(:destroy) }

  it 'is valid with name and email' do
    user = described_class.new(name: 'Test User', email: 'test@example.com')
    expect(user).to be_valid
  end

  it 'is invalid without an email' do
    user = described_class.new(name: 'Test User')
    expect(user).not_to be_valid
  end
end
