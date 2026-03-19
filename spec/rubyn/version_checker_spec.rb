# frozen_string_literal: true

require "webmock/rspec"

RSpec.describe Rubyn::VersionChecker do
  let(:cache_file) { File.join(Dir.tmpdir, "rubyn_test_version_cache.json") }

  before do
    stub_const("Rubyn::VersionChecker::CACHE_FILE", cache_file)
    FileUtils.rm_f(cache_file)
  end

  after { FileUtils.rm_f(cache_file) }

  describe ".check" do
    it "fetches the latest version from RubyGems" do
      stub_request(:get, "https://rubygems.org/api/v1/versions/rubyn/latest.json")
        .to_return(status: 200, body: { version: "1.0.0" }.to_json, headers: { "Content-Type" => "application/json" })

      expect(described_class.check).to eq("1.0.0")
    end

    it "caches the result" do
      stub_request(:get, "https://rubygems.org/api/v1/versions/rubyn/latest.json")
        .to_return(status: 200, body: { version: "1.0.0" }.to_json, headers: { "Content-Type" => "application/json" })

      described_class.check
      described_class.check # second call should use cache

      expect(WebMock).to have_requested(:get, "https://rubygems.org/api/v1/versions/rubyn/latest.json").once
    end

    it "returns nil when RubyGems is unreachable" do
      stub_request(:get, "https://rubygems.org/api/v1/versions/rubyn/latest.json")
        .to_return(status: 503)

      expect(described_class.check).to be_nil
    end

    it "returns nil on network error" do
      stub_request(:get, "https://rubygems.org/api/v1/versions/rubyn/latest.json")
        .to_raise(Errno::ECONNREFUSED)

      expect(described_class.check).to be_nil
    end
  end

  describe ".update_available?" do
    it "returns true when a newer version exists" do
      stub_request(:get, "https://rubygems.org/api/v1/versions/rubyn/latest.json")
        .to_return(status: 200, body: { version: "99.0.0" }.to_json, headers: { "Content-Type" => "application/json" })

      expect(described_class.update_available?).to be true
    end

    it "returns false when on the latest version" do
      stub_request(:get, "https://rubygems.org/api/v1/versions/rubyn/latest.json")
        .to_return(status: 200, body: { version: Rubyn::VERSION }.to_json, headers: { "Content-Type" => "application/json" })

      expect(described_class.update_available?).to be false
    end

    it "returns false when check fails" do
      stub_request(:get, "https://rubygems.org/api/v1/versions/rubyn/latest.json")
        .to_raise(Errno::ECONNREFUSED)

      expect(described_class.update_available?).to be false
    end
  end

  describe ".update_message" do
    it "returns a message when an update is available" do
      stub_request(:get, "https://rubygems.org/api/v1/versions/rubyn/latest.json")
        .to_return(status: 200, body: { version: "2.0.0" }.to_json, headers: { "Content-Type" => "application/json" })

      msg = described_class.update_message
      expect(msg).to include("2.0.0")
      expect(msg).to include(Rubyn::VERSION)
      expect(msg).to include("gem update rubyn")
    end

    it "returns nil when on the latest version" do
      stub_request(:get, "https://rubygems.org/api/v1/versions/rubyn/latest.json")
        .to_return(status: 200, body: { version: Rubyn::VERSION }.to_json, headers: { "Content-Type" => "application/json" })

      expect(described_class.update_message).to be_nil
    end

    it "returns nil when check fails" do
      stub_request(:get, "https://rubygems.org/api/v1/versions/rubyn/latest.json")
        .to_raise(Errno::ECONNREFUSED)

      expect(described_class.update_message).to be_nil
    end
  end
end
