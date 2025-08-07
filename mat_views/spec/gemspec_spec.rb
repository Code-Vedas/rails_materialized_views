# frozen_string_literal: true

RSpec.describe 'mat_views.gemspec' do # rubocop:disable RSpec/DescribeClass
  subject(:spec) { Gem::Specification.load('mat_views.gemspec') }

  it 'has mat_view name' do
    expect(spec.name).to eq('mat_views')
  end

  it 'has mat_view version' do
    expect(spec.version).to eq(MatViews::VERSION)
  end
end
