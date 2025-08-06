RSpec.describe "mat_views.gemspec" do
  it "is valid and can be loaded" do
    spec = Gem::Specification.load("mat_views.gemspec")
    expect(spec.name).to eq("mat_views")
    expect(spec.version).to be_a(Gem::Version)
  end
end
