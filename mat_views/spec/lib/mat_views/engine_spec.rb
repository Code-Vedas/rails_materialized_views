# frozen_string_literal: true

RSpec.describe MatViews::Engine do
  it 'inherits from Rails::Engine' do
    expect(described_class < Rails::Engine).to be(true)
  end

  it 'isolates the MatViews namespace' do
    expect(described_class.isolated).to be(true)
  end
end
