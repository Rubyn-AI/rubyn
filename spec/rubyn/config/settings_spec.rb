# frozen_string_literal: true

RSpec.describe Rubyn::Config::Settings do
  let(:tmpdir) { Dir.mktmpdir }
  let(:settings_file) { File.join(tmpdir, "config.yml") }

  before do
    stub_const("Rubyn::Config::Settings::SETTINGS_DIR", tmpdir)
    stub_const("Rubyn::Config::Settings::SETTINGS_FILE", settings_file)
  end

  after do
    FileUtils.rm_rf(tmpdir)
  end

  describe ".all" do
    it "returns defaults when no settings file exists" do
      settings = described_class.all
      expect(settings["default_model"]).to eq("haiku")
      expect(settings["auto_apply"]).to be false
      expect(settings["output_format"]).to eq("diff")
    end
  end

  describe ".get" do
    it "returns a specific setting" do
      expect(described_class.get("default_model")).to eq("haiku")
    end

    it "returns nil for unknown keys" do
      expect(described_class.get("nonexistent")).to be_nil
    end
  end

  describe ".set" do
    it "writes a setting to file" do
      described_class.set("output_format", "full")
      expect(described_class.get("output_format")).to eq("full")
    end

    it "coerces boolean strings" do
      described_class.set("auto_apply", "true")
      expect(described_class.get("auto_apply")).to be true
    end

    it "coerces integer strings" do
      described_class.set("some_number", "42")
      expect(described_class.get("some_number")).to eq(42)
    end

    it "persists across reads" do
      described_class.set("default_model", "sonnet")
      content = YAML.safe_load_file(settings_file)
      expect(content["default_model"]).to eq("sonnet")
    end
  end
end
