# frozen_string_literal: true

RSpec.describe Rubyn::Commands::Refactor do
  let(:tmpdir) { Dir.mktmpdir }
  let(:command) { described_class.new }
  let(:test_file) { File.join(tmpdir, "app", "models", "order.rb") }

  before do
    stub_const("Rubyn::Config::Credentials::CREDENTIALS_DIR", tmpdir)
    stub_const("Rubyn::Config::Credentials::CREDENTIALS_FILE", File.join(tmpdir, "credentials"))
    Rubyn::Config::Credentials.store(api_key: "rk_test")
    Rubyn::Config::ProjectConfig.write({ "project_token" => "rprj_test", "project_id" => 1 }, tmpdir)
    allow(Dir).to receive(:pwd).and_return(tmpdir)

    FileUtils.mkdir_p(File.dirname(test_file))
    File.write(test_file, "class Order; end")

    allow($stdout).to receive(:write)
    allow($stdout).to receive(:print)
    allow($stdin).to receive(:gets).and_return("n\n")

    stub_auth_verify
    stub_streaming_refactor(content: "refactored content")
  end

  after do
    FileUtils.rm_rf(tmpdir)
  end

  describe "#execute" do
    it "calls the refactor API with file content" do
      command.execute(test_file)
      expect(WebMock).to have_requested(:post, "https://api.rubyn.dev/api/v1/ai/refactor")
    end

    it "reports error for non-existent file" do
      expect { command.execute("/nonexistent/file.rb") }.not_to raise_error
    end

    it "raises error when not configured" do
      allow(Rubyn::Config::Credentials).to receive(:exists?).and_return(false)
      allow(Rubyn::Config::ProjectConfig).to receive(:exists?).and_return(false)
      expect { command.execute(test_file) }.to raise_error(Rubyn::ConfigurationError)
    end
  end
end
