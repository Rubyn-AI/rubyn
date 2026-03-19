# frozen_string_literal: true

RSpec.describe Rubyn::Commands::Config do
  let(:tmpdir) { Dir.mktmpdir }
  let(:command) { described_class.new }
  let(:formatter) { Rubyn::Output::Formatter }

  before do
    stub_const("Rubyn::Config::Settings::SETTINGS_DIR", tmpdir)
    stub_const("Rubyn::Config::Settings::SETTINGS_FILE", File.join(tmpdir, "config.yml"))

    allow($stdout).to receive(:write)
    allow($stdout).to receive(:print)
  end

  after do
    FileUtils.rm_rf(tmpdir)
  end

  describe "#execute" do
    context "with no arguments (display_all)" do
      it "displays all configuration settings" do
        expect(formatter).to receive(:header).with("Rubyn Configuration")
        expect(formatter).to receive(:info).at_least(:once)
        command.execute
      end

      it "shows each default setting" do
        expect(formatter).to receive(:header)
        expect(formatter).to receive(:info).with(/default_model/)
        expect(formatter).to receive(:info).with(/auto_apply/)
        expect(formatter).to receive(:info).with(/output_format/)
        command.execute
      end
    end

    context "with key only (display_key)" do
      it "displays value for a known key" do
        expect(formatter).to receive(:info).with("default_model: haiku")
        command.execute("default_model")
      end

      it "shows warning for an unknown key" do
        expect(formatter).to receive(:warning).with("Unknown key: bogus_key")
        expect(formatter).to receive(:info).with(/Valid keys:/)
        command.execute("bogus_key")
      end
    end

    context "with key and value (set_key)" do
      it "sets a valid key" do
        expect(formatter).to receive(:success).with("default_model set to sonnet")
        command.execute("default_model", "sonnet")
      end

      it "persists the value" do
        command.execute("default_model", "sonnet")
        expect(Rubyn::Config::Settings.get("default_model")).to eq("sonnet")
      end

      it "rejects an invalid key" do
        expect(formatter).to receive(:error).with("Invalid key: bad_key")
        expect(formatter).to receive(:info).with(/Valid keys:/)
        command.execute("bad_key", "value")
      end

      it "does not persist an invalid key" do
        command.execute("bad_key", "value")
        expect(Rubyn::Config::Settings.get("bad_key")).to be_nil
      end

      it "coerces boolean string values" do
        command.execute("auto_apply", "true")
        expect(Rubyn::Config::Settings.get("auto_apply")).to be true
      end
    end
  end
end
