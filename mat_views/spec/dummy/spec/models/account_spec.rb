# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

RSpec.describe Account, type: :model do
  it { is_expected.to belong_to(:user) }

  it 'is valid with user, plan, and status' do
    user = User.create!(name: 'Test', email: 't@example.com')
    account = described_class.new(user: user, plan: 'pro', status: 'active')
    expect(account).to be_valid
  end

  it 'is invalid without a user' do
    account = described_class.new(plan: 'pro', status: 'active')
    expect(account).not_to be_valid
  end
end
