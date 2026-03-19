# frozen_string_literal: true

require "open3"

RSpec.describe Rubyn::Tools::RunTests do
  let(:tmpdir) { Dir.mktmpdir }
  let(:tool) { described_class.new(tmpdir) }

  after { FileUtils.rm_rf(tmpdir) }

  describe "#execute" do
    context "when spec/ directory exists (rspec)" do
      before { FileUtils.mkdir_p(File.join(tmpdir, "spec")) }

      it "runs rspec" do
        status = instance_double(Process::Status, exitstatus: 0)
        allow(Open3).to receive(:capture3)
          .with("bundle exec rspec", chdir: tmpdir)
          .and_return(["3 examples, 0 failures", "", status])

        result = tool.call({})
        expect(result[:success]).to be true
        expect(result[:command]).to eq("bundle exec rspec")
        expect(result[:passed]).to be true
        expect(result[:exit_code]).to eq(0)
      end

      it "appends path when provided" do
        status = instance_double(Process::Status, exitstatus: 0)
        allow(Open3).to receive(:capture3)
          .with("bundle exec rspec spec/models/user_spec.rb", chdir: tmpdir)
          .and_return(["1 example, 0 failures", "", status])

        result = tool.call("path" => "spec/models/user_spec.rb")
        expect(result[:command]).to eq("bundle exec rspec spec/models/user_spec.rb")
      end

      it "appends options when provided" do
        status = instance_double(Process::Status, exitstatus: 0)
        allow(Open3).to receive(:capture3)
          .with("bundle exec rspec --fail-fast", chdir: tmpdir)
          .and_return(["OK", "", status])

        result = tool.call("options" => "--fail-fast")
        expect(result[:command]).to eq("bundle exec rspec --fail-fast")
      end

      it "appends both path and options" do
        status = instance_double(Process::Status, exitstatus: 0)
        allow(Open3).to receive(:capture3)
          .with("bundle exec rspec spec/models --format doc", chdir: tmpdir)
          .and_return(["OK", "", status])

        result = tool.call("path" => "spec/models", "options" => "--format doc")
        expect(result[:command]).to eq("bundle exec rspec spec/models --format doc")
      end

      it "reports test failures with exit code" do
        status = instance_double(Process::Status, exitstatus: 1)
        allow(Open3).to receive(:capture3)
          .with("bundle exec rspec", chdir: tmpdir)
          .and_return(["1 example, 1 failure", "Failed", status])

        result = tool.call({})
        expect(result[:success]).to be true
        expect(result[:passed]).to be false
        expect(result[:exit_code]).to eq(1)
        expect(result[:stderr]).to eq("Failed")
      end

      it "ignores blank path" do
        status = instance_double(Process::Status, exitstatus: 0)
        allow(Open3).to receive(:capture3)
          .with("bundle exec rspec", chdir: tmpdir)
          .and_return(["OK", "", status])

        result = tool.call("path" => "  ")
        expect(result[:command]).to eq("bundle exec rspec")
      end

      it "ignores blank options" do
        status = instance_double(Process::Status, exitstatus: 0)
        allow(Open3).to receive(:capture3)
          .with("bundle exec rspec", chdir: tmpdir)
          .and_return(["OK", "", status])

        result = tool.call("options" => "  ")
        expect(result[:command]).to eq("bundle exec rspec")
      end
    end

    context "when test/ directory exists (minitest)" do
      before { FileUtils.mkdir_p(File.join(tmpdir, "test")) }

      it "runs rails test" do
        status = instance_double(Process::Status, exitstatus: 0)
        allow(Open3).to receive(:capture3)
          .with("bundle exec rails test", chdir: tmpdir)
          .and_return(["0 failures", "", status])

        result = tool.call({})
        expect(result[:success]).to be true
        expect(result[:command]).to eq("bundle exec rails test")
        expect(result[:passed]).to be true
      end

      it "appends path for minitest" do
        status = instance_double(Process::Status, exitstatus: 0)
        allow(Open3).to receive(:capture3)
          .with("bundle exec rails test test/models/user_test.rb", chdir: tmpdir)
          .and_return(["OK", "", status])

        result = tool.call("path" => "test/models/user_test.rb")
        expect(result[:command]).to eq("bundle exec rails test test/models/user_test.rb")
      end
    end

    context "when no test directory exists" do
      it "returns error" do
        result = tool.call({})
        expect(result[:success]).to be false
        expect(result[:error]).to include("No test framework detected")
      end
    end

    context "when Open3 raises an exception" do
      before { FileUtils.mkdir_p(File.join(tmpdir, "spec")) }

      it "handles the exception gracefully" do
        allow(Open3).to receive(:capture3).and_raise(Errno::ENOENT, "bundle not found")

        result = tool.call({})
        expect(result[:success]).to be false
        expect(result[:error]).to include("Failed to run tests")
      end
    end

    it "requires confirmation" do
      expect(tool.requires_confirmation?).to be true
    end
  end
end
