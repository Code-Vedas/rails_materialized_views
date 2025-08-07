# frozen_string_literal: true

RSpec.describe MatViews::MatViewDefinition do
  subject(:model) { described_class.new(name: 'user_activity', sql: 'SELECT * FROM users') }

  it 'is valid with valid attributes' do
    expect(model).to be_valid
  end

  it 'requires a name' do
    model.name = nil
    expect(model).not_to be_valid
  end

  it 'requires a unique name' do
    described_class.create!(name: 'user_activity', sql: 'SELECT 1')
    expect(model).not_to be_valid
  end

  it 'requires SQL starting with SELECT' do
    model.sql = 'UPDATE users SET active = true'
    expect(model).not_to be_valid
  end

  it 'has many refresh runs' do
    assoc = described_class.reflect_on_association(:mat_view_refresh_runs)
    expect(assoc.macro).to eq(:has_many)
    expect(assoc.options[:dependent]).to eq(:destroy)
  end
end
