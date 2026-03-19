# frozen_string_literal: true

RSpec.describe Rubyn::Config::ProjectConfig do
  let(:tmpdir) { Dir.mktmpdir }

  after do
    FileUtils.rm_rf(tmpdir)
  end

  describe ".write and .read" do
    it "writes and reads project config" do
      described_class.write({ "project_token" => "rprj_abc", "project_id" => 42 }, tmpdir)
      config = described_class.read(tmpdir)
      expect(config["project_token"]).to eq("rprj_abc")
      expect(config["project_id"]).to eq(42)
    end

    it "creates .rubyn directory" do
      described_class.write({ "project_token" => "rprj_abc" }, tmpdir)
      expect(Dir.exist?(File.join(tmpdir, ".rubyn"))).to be true
    end
  end

  describe ".exists?" do
    it "returns false when config does not exist" do
      expect(described_class.exists?(tmpdir)).to be false
    end

    it "returns true when config exists" do
      described_class.write({ "project_token" => "rprj_abc" }, tmpdir)
      expect(described_class.exists?(tmpdir)).to be true
    end
  end

  describe ".project_token" do
    it "returns the project token" do
      described_class.write({ "project_token" => "rprj_xyz" }, tmpdir)
      expect(described_class.project_token(tmpdir)).to eq("rprj_xyz")
    end
  end

  describe ".project_id" do
    it "returns the project id" do
      described_class.write({ "project_id" => 99 }, tmpdir)
      expect(described_class.project_id(tmpdir)).to eq(99)
    end
  end
end
