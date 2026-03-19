# frozen_string_literal: true

RSpec.describe Rubyn::Commands::Base do
  let(:tmpdir) { Dir.mktmpdir }
  let(:formatter) { Rubyn::Output::Formatter }

  # Create a concrete subclass since Base methods are private
  let(:command_class) do
    Class.new(described_class) do
      public :ensure_configured!, :ensure_credentials!, :relative_to_project, :build_context_files, :project_token
    end
  end
  let(:command) { command_class.new }

  before do
    stub_const("Rubyn::Config::Credentials::CREDENTIALS_DIR", tmpdir)
    stub_const("Rubyn::Config::Credentials::CREDENTIALS_FILE", File.join(tmpdir, "credentials"))
    allow(Dir).to receive(:pwd).and_return(tmpdir)

    allow($stdout).to receive(:write)
    allow($stdout).to receive(:print)
  end

  after do
    FileUtils.rm_rf(tmpdir)
  end

  describe "#ensure_configured!" do
    context "when credentials and project config exist" do
      before do
        Rubyn::Config::Credentials.store(api_key: "rk_test")
        Rubyn::Config::ProjectConfig.write({ "project_token" => "rprj_test" }, tmpdir)
      end

      it "does not raise" do
        expect { command.ensure_configured! }.not_to raise_error
      end
    end

    context "when credentials are missing" do
      before do
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with("RUBYN_API_KEY").and_return(nil)
      end

      it "raises ConfigurationError" do
        expect { command.ensure_configured! }.to raise_error(Rubyn::ConfigurationError, "Not configured")
      end

      it "displays an error message" do
        expect(formatter).to receive(:error).with(/Not configured/)
        expect { command.ensure_configured! }.to raise_error(Rubyn::ConfigurationError)
      end
    end

    context "when project config is missing" do
      before do
        Rubyn::Config::Credentials.store(api_key: "rk_test")
        # No project config written
      end

      it "raises ConfigurationError" do
        expect { command.ensure_configured! }.to raise_error(Rubyn::ConfigurationError)
      end
    end
  end

  describe "#ensure_credentials!" do
    context "when credentials exist" do
      before do
        Rubyn::Config::Credentials.store(api_key: "rk_test")
      end

      it "does not raise" do
        expect { command.ensure_credentials! }.not_to raise_error
      end
    end

    context "when credentials are missing" do
      before do
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with("RUBYN_API_KEY").and_return(nil)
      end

      it "raises ConfigurationError" do
        expect { command.ensure_credentials! }.to raise_error(Rubyn::ConfigurationError, "Not configured")
      end
    end
  end

  describe "#relative_to_project" do
    it "strips the project root from an absolute path" do
      abs_path = File.join(tmpdir, "app", "models", "user.rb")
      expect(command.relative_to_project(abs_path)).to eq("app/models/user.rb")
    end

    it "returns relative path when given absolute path under project root" do
      allow(Dir).to receive(:pwd).and_return(tmpdir)
      abs_path = File.join(tmpdir, "lib", "service.rb")
      result = command.relative_to_project(abs_path)
      expect(result).to eq("lib/service.rb")
    end
  end

  describe "#build_context_files" do
    it "returns an array of context file hashes" do
      # Create a file and its related file
      FileUtils.mkdir_p(File.join(tmpdir, "lib"))
      File.write(File.join(tmpdir, "lib", "foo.rb"), "class Foo; end")
      FileUtils.mkdir_p(File.join(tmpdir, "spec"))
      File.write(File.join(tmpdir, "spec", "foo_spec.rb"), "describe Foo")

      resolver = instance_double(Rubyn::Context::FileResolver)
      allow(Rubyn::Context::FileResolver).to receive(:new).and_return(resolver)
      allow(resolver).to receive(:resolve).with("lib/foo.rb").and_return(["spec/foo_spec.rb"])

      builder = instance_double(Rubyn::Context::ContextBuilder)
      allow(Rubyn::Context::ContextBuilder).to receive(:new).and_return(builder)
      allow(builder).to receive(:build).with("lib/foo.rb", ["spec/foo_spec.rb"])
                                       .and_return({ "lib/foo.rb" => "class Foo; end", "spec/foo_spec.rb" => "describe Foo" })

      result = command.build_context_files("lib/foo.rb")

      expect(result).to be_an(Array)
      # Should not include the target file itself
      expect(result.map { |f| f[:file_path] }).not_to include("lib/foo.rb")
      expect(result).to include({ file_path: "spec/foo_spec.rb", code: "describe Foo" })
    end

    it "excludes the target file from context" do
      resolver = instance_double(Rubyn::Context::FileResolver)
      allow(Rubyn::Context::FileResolver).to receive(:new).and_return(resolver)
      allow(resolver).to receive(:resolve).and_return([])

      builder = instance_double(Rubyn::Context::ContextBuilder)
      allow(Rubyn::Context::ContextBuilder).to receive(:new).and_return(builder)
      allow(builder).to receive(:build).and_return({ "target.rb" => "code" })

      result = command.build_context_files("target.rb")
      expect(result).to be_empty
    end
  end

  describe "#project_token" do
    it "returns the project token from config" do
      Rubyn::Config::ProjectConfig.write({ "project_token" => "rprj_abc123" }, tmpdir)
      expect(command.project_token).to eq("rprj_abc123")
    end

    it "returns nil when no project config exists" do
      expect(command.project_token).to be_nil
    end
  end
end
