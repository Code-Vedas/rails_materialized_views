# frozen_string_literal: true

RSpec.describe MatViews do
  it 'defines the MatViews module' do
    expect(defined?(MatViews)).to eq('constant') # rubocop:disable RSpec/DescribedClass
  end

  it 'has a version number' do
    expect(MatViews::VERSION).not_to be_nil
  end
end
