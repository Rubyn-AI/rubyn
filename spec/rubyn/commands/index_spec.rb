# frozen_string_literal: true

RSpec.describe Rubyn::Commands::Index do
  let(:tmpdir) { Dir.mktmpdir }
  let(:command) { described_class.new }

  before do
    stub_const("Rubyn::Config::Credentials::CREDENTIALS_DIR", tmpdir)
    stub_const("Rubyn::Config::Credentials::CREDENTIALS_FILE", File.join(tmpdir, "credentials"))
    Rubyn::Config::Credentials.store(api_key: "rk_test")
    Rubyn::Config::ProjectConfig.write({ "project_token" => "rprj_test", "project_id" => 1 }, tmpdir)
    allow(Dir).to receive(:pwd).and_return(tmpdir)

    FileUtils.mkdir_p(File.join(tmpdir, "lib"))
    File.write(File.join(tmpdir, "lib", "example.rb"), "class Example; end")

    allow($stdout).to receive(:write)
    allow($stdout).to receive(:print)

    stub_index_project
  end

  after do
    FileUtils.rm_rf(tmpdir)
  end

  describe "#execute" do
    it "analyses changed files" do
      command.execute
      expect(WebMock).to have_requested(:post, "https://api.rubyn.dev/api/v1/projects/index")
    end

    it "force re-analyses all files" do
      command.execute(force: true)
      expect(WebMock).to have_requested(:post, "https://api.rubyn.dev/api/v1/projects/index")
    end

    it "skips when nothing changed" do
      command.execute(force: true) # first run indexes
      WebMock.reset!
      stub_index_project
      command.execute # second run should skip (files unchanged)
      expect(WebMock).not_to have_requested(:post, "https://api.rubyn.dev/api/v1/projects/index")
    end

    it "displays API errors gracefully" do
      indexer = instance_double(Rubyn::Context::CodebaseIndexer)
      allow(Rubyn::Context::CodebaseIndexer).to receive(:new).and_return(indexer)
      allow(indexer).to receive(:index).and_raise(Rubyn::APIError, "Upload failed")
      formatter = Rubyn::Output::Formatter
      expect(formatter).to receive(:error).with("Upload failed")
      command.execute
    end
  end

  describe "#truncate_path" do
    it "returns short paths unchanged" do
      result = command.send(:truncate_path, "lib/foo.rb", 40)
      expect(result).to eq("lib/foo.rb")
    end

    it "truncates long paths with ellipsis prefix" do
      long_path = "app/services/very/deeply/nested/directory/structure/some_file.rb"
      result = command.send(:truncate_path, long_path, 30)
      expect(result).to start_with("...")
      expect(result.length).to eq(30)
    end
  end
end
