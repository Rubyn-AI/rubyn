# frozen_string_literal: true

RSpec.describe Rubyn::Tools::Executor do
  let(:tmpdir) { Dir.mktmpdir }
  let(:executor) { described_class.new(tmpdir, auto_confirm: true) }

  before do
    File.write(File.join(tmpdir, "test.rb"), "puts 'hello'")
  end

  after do
    FileUtils.rm_rf(tmpdir)
  end

  describe "#execute" do
    it "executes a known tool" do
      result = executor.execute("read_file", { "path" => "test.rb" })
      expect(result[:success]).to be true
      expect(result[:content]).to eq("puts 'hello'")
    end

    it "returns error for unknown tool" do
      result = executor.execute("nonexistent", {})
      expect(result[:success]).to be false
      expect(result[:error]).to include("Unknown tool")
    end

    it "catches exceptions and returns error" do
      read_file_tool = instance_double(Rubyn::Tools::ReadFile)
      allow(Rubyn::Tools::ReadFile).to receive(:new).and_return(read_file_tool)
      allow(read_file_tool).to receive(:requires_confirmation?).and_return(false)
      allow(read_file_tool).to receive(:call).and_raise(StandardError, "boom")
      result = executor.execute("read_file", { "path" => "test.rb" })
      expect(result[:success]).to be false
      expect(result[:error]).to include("boom")
    end

    it "uses server_requires_confirmation when provided" do
      allow($stdin).to receive(:gets).and_return("n\n")
      allow($stdout).to receive(:write)
      allow($stdout).to receive(:print)

      # read_file normally doesn't need confirmation, but server overrides
      result = executor.execute("read_file", { "path" => "test.rb" }, server_requires_confirmation: true)
      # auto_confirm is true on this executor, so it should still succeed
      expect(result[:success]).to be true
    end

    it "respects server_requires_confirmation false override" do
      executor_no_auto = described_class.new(tmpdir, auto_confirm: false)
      # write_file normally requires confirmation, but server says no
      result = executor_no_auto.execute("write_file", { "path" => "override.rb", "content" => "x" },
                                        server_requires_confirmation: false)
      expect(result[:success]).to be true
    end
  end

  describe "confirmation" do
    let(:executor_with_confirm) { described_class.new(tmpdir, auto_confirm: false) }

    it "denies destructive actions when user says no" do
      allow($stdin).to receive(:gets).and_return("n\n")
      allow($stdout).to receive(:write)
      allow($stdout).to receive(:print)
      result = executor_with_confirm.execute("write_file", { "path" => "new.rb", "content" => "code" })
      expect(result[:success]).to be false
      expect(result[:error]).to eq("denied_by_user")
    end

    it "allows destructive actions when user says yes" do
      allow($stdin).to receive(:gets).and_return("y\n")
      allow($stdout).to receive(:write)
      allow($stdout).to receive(:print)
      result = executor_with_confirm.execute("write_file", { "path" => "new.rb", "content" => "code" })
      expect(result[:success]).to be true
    end

    it "skips confirmation for read-only tools" do
      result = executor_with_confirm.execute("read_file", { "path" => "test.rb" })
      expect(result[:success]).to be true
    end
  end

  describe "#format_action" do
    # Access the private method for testing
    let(:executor_instance) { described_class.new(tmpdir) }

    def format(tool_name, params)
      executor_instance.send(:format_action, tool_name, params)
    end

    it "formats write_file actions" do
      expect(format("write_file", { "path" => "app/foo.rb" })).to eq("write to app/foo.rb")
    end

    it "formats create_file actions" do
      expect(format("create_file", { "path" => "new.rb" })).to eq("write to new.rb")
    end

    it "formats patch_file actions" do
      expect(format("patch_file", { "path" => "target.rb" })).to eq("edit target.rb")
    end

    it "formats delete_file actions" do
      expect(format("delete_file", { "path" => "doomed.rb" })).to eq("delete doomed.rb")
    end

    it "formats move_file actions" do
      expect(format("move_file", { "source" => "old.rb", "destination" => "new.rb" })).to eq("move old.rb to new.rb")
    end

    it "formats run_command actions" do
      expect(format("run_command", { "command" => "ls -la" })).to eq("run: ls -la")
    end

    it "formats run_tests actions with path" do
      expect(format("run_tests", { "path" => "spec/models" })).to eq("run tests: spec/models")
    end

    it "formats run_tests actions without path" do
      expect(format("run_tests", {})).to eq("run tests: full suite")
    end

    it "formats rails_generate actions" do
      expect(format("rails_generate", { "generator" => "model", "args" => "User name:string" }))
        .to eq("rails generate model User name:string")
    end

    it "formats rails_migrate actions" do
      expect(format("rails_migrate", {})).to eq("rails db:migrate")
    end

    it "formats bundle_add actions" do
      expect(format("bundle_add", { "gem_name" => "sidekiq" })).to eq("add gem 'sidekiq' to Gemfile")
    end

    it "formats git_commit actions" do
      expect(format("git_commit", { "message" => "fix bug" })).to eq("git commit: fix bug")
    end

    it "formats git_create_branch actions" do
      expect(format("git_create_branch", { "branch_name" => "feature/x" })).to eq("create branch: feature/x")
    end

    it "formats unknown tools with a fallback" do
      result = format("some_custom_tool", { "foo" => "bar" })
      expect(result).to include("some_custom_tool")
    end
  end
end
