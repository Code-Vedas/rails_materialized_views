RSpec.describe MatViews::Engine do
  it "inherits from Rails::Engine" do
    expect(MatViews::Engine < Rails::Engine).to be(true)
  end

  it "isolates the MatViews namespace" do
    expect(MatViews::Engine.isolated).to be(true)
  end
end
