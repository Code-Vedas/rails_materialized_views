# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

require 'rails_helper'

RSpec.describe Session, type: :model do
  it { is_expected.to belong_to(:user) }

  it 'is valid with user and session_token' do
    user = User.create!(name: 'Test', email: 't@example.com')
    session = described_class.new(
      user: user,
      session_token: 'token123',
      started_at: 2.days.ago,
      ended_at: 1.day.ago
    )
    expect(session).to be_valid
  end

  it 'is invalid without a user' do
    session = described_class.new(session_token: 'token123')
    expect(session).not_to be_valid
  end
end
