# frozen_string_literal: true

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
