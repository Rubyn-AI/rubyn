# frozen_string_literal: true

RSpec.describe "Shell tools" do
  let(:tmpdir) { Dir.mktmpdir }

  after do
    FileUtils.rm_rf(tmpdir)
  end

  describe Rubyn::Tools::RunCommand do
    let(:tool) { described_class.new(tmpdir) }

    it "executes a command and returns output" do
      result = tool.call("command" => "echo hello")
      expect(result[:success]).to be true
      expect(result[:stdout]).to include("hello")
      expect(result[:exit_code]).to eq(0)
    end

    it "captures stderr" do
      result = tool.call("command" => "echo error >&2")
      expect(result[:stderr]).to include("error")
    end

    it "reports non-zero exit code" do
      result = tool.call("command" => "exit 1")
      expect(result[:success]).to be true # tool succeeded, command failed
      expect(result[:exit_code]).to eq(1)
    end

    it "requires confirmation" do
      expect(tool.requires_confirmation?).to be true
    end
  end

  describe Rubyn::Tools::RunTests do
    let(:tool) { described_class.new(tmpdir) }

    before do
      FileUtils.mkdir_p(File.join(tmpdir, "spec"))
    end

    it "detects rspec when spec/ exists" do
      result = tool.call({})
      # Will fail because no Gemfile, but should attempt rspec
      expect(result[:command]).to include("rspec")
    end

    it "requires confirmation" do
      expect(tool.requires_confirmation?).to be true
    end
  end
end
