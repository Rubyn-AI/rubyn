require "spec_helper"

RSpec.describe MyGem::Client do
  it "initializes with api key" do
    client = described_class.new(api_key: "test")
    expect(client).to be_a(MyGem::Client)
  end
end
