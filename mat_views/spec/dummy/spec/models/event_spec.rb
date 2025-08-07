# frozen_string_literal: true

RSpec.describe Event, type: :model do
  it { is_expected.to belong_to(:user) }

  it 'is valid with user and event_type' do
    user = User.create!(name: 'Test', email: 't@example.com')
    event = described_class.new(user: user, event_type: 'login', occurred_at: Time.current)
    expect(event).to be_valid
  end

  it 'is invalid without a user' do
    event = described_class.new(event_type: 'click', occurred_at: Time.current)
    expect(event).not_to be_valid
  end
end
