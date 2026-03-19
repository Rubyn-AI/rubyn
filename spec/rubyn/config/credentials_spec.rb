# frozen_string_literal: true

RSpec.describe Rubyn::Config::Credentials do
  let(:tmpdir) { Dir.mktmpdir }
  let(:creds_file) { File.join(tmpdir, "credentials") }

  before do
    stub_const("Rubyn::Config::Credentials::CREDENTIALS_DIR", tmpdir)
    stub_const("Rubyn::Config::Credentials::CREDENTIALS_FILE", creds_file)
    ENV.delete("RUBYN_API_KEY")
  end

  after do
    FileUtils.rm_rf(tmpdir)
  end

  describe ".store" do
    it "writes credentials to file" do
      described_class.store(api_key: "rk_test123")
      expect(File.exist?(creds_file)).to be true
      content = YAML.safe_load_file(creds_file)
      expect(content["api_key"]).to eq("rk_test123")
    end

    it "sets file permissions to 0600" do
      described_class.store(api_key: "rk_test123")
      mode = File.stat(creds_file).mode & 0o777
      expect(mode).to eq(0o600)
    end
  end

  describe ".api_key" do
    it "returns nil when no credentials exist" do
      expect(described_class.api_key).to be_nil
    end

    it "returns stored API key" do
      described_class.store(api_key: "rk_stored")
      expect(described_class.api_key).to eq("rk_stored")
    end

    it "prefers environment variable over stored key" do
      described_class.store(api_key: "rk_stored")
      ENV["RUBYN_API_KEY"] = "rk_env"
      expect(described_class.api_key).to eq("rk_env")
      ENV.delete("RUBYN_API_KEY")
    end
  end

  describe ".exists?" do
    it "returns false when no key exists" do
      expect(described_class.exists?).to be false
    end

    it "returns true when key is stored" do
      described_class.store(api_key: "rk_test")
      expect(described_class.exists?).to be true
    end
  end
end
