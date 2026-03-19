# frozen_string_literal: true

RSpec.describe Rubyn::Commands::Review do
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

    stub_auth_verify
    stub_streaming_review(content: "review findings")
  end

  after do
    FileUtils.rm_rf(tmpdir)
  end

  describe "#execute" do
    it "calls the review API for a single file" do
      command.execute(test_file)
      expect(WebMock).to have_requested(:post, "https://api.rubyn.dev/api/v1/ai/review")
    end

    it "reviews all .rb files in a directory" do
      command.execute(File.join(tmpdir, "app"))
      expect(WebMock).to have_requested(:post, "https://api.rubyn.dev/api/v1/ai/review").at_least_once
    end

    it "reports error for empty directory" do
      empty_dir = File.join(tmpdir, "empty")
      FileUtils.mkdir_p(empty_dir)
      expect { command.execute(empty_dir) }.not_to raise_error
    end
  end
end
