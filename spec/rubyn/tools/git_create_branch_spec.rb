# frozen_string_literal: true

require "open3"

RSpec.describe Rubyn::Tools::GitCreateBranch do
  let(:tmpdir) { Dir.mktmpdir }
  let(:tool) { described_class.new(tmpdir) }

  before do
    system("git init #{tmpdir}", out: File::NULL, err: File::NULL)
    system("git -C #{tmpdir} config user.email 'test@test.com'", out: File::NULL, err: File::NULL)
    system("git -C #{tmpdir} config user.name 'Test'", out: File::NULL, err: File::NULL)
    File.write(File.join(tmpdir, "initial.rb"), "# initial")
    system("git -C #{tmpdir} add . && git -C #{tmpdir} commit -m 'initial'", out: File::NULL, err: File::NULL)
  end

  after { FileUtils.rm_rf(tmpdir) }

  describe "#execute" do
    it "creates and checks out a new branch" do
      result = tool.call("branch_name" => "feature/new-thing")
      expect(result[:success]).to be true
      expect(result[:branch]).to eq("feature/new-thing")
    end

    it "requires branch_name parameter" do
      result = tool.call({})
      expect(result[:success]).to be false
      expect(result[:error]).to include("branch_name is required")
    end

    it "rejects empty branch_name" do
      result = tool.call("branch_name" => "  ")
      expect(result[:success]).to be false
      expect(result[:error]).to include("branch_name is required")
    end

    it "rejects branch names with spaces" do
      result = tool.call("branch_name" => "bad branch")
      expect(result[:success]).to be false
      expect(result[:error]).to include("Invalid branch name")
    end

    it "rejects branch names with special characters" do
      result = tool.call("branch_name" => "feat@ure!")
      expect(result[:success]).to be false
      expect(result[:error]).to include("Invalid branch name")
    end

    it "allows branch names with hyphens, underscores, and slashes" do
      result = tool.call("branch_name" => "feature/my_branch-123")
      expect(result[:success]).to be true
      expect(result[:branch]).to eq("feature/my_branch-123")
    end

    it "creates a branch from a specific ref" do
      # Create a second branch to use as a base
      system("git -C #{tmpdir} checkout -b base-branch", out: File::NULL, err: File::NULL)
      File.write(File.join(tmpdir, "base.rb"), "# base")
      system("git -C #{tmpdir} add . && git -C #{tmpdir} commit -m 'base commit'", out: File::NULL, err: File::NULL)
      system("git -C #{tmpdir} checkout master 2>/dev/null || git -C #{tmpdir} checkout main", out: File::NULL, err: File::NULL)

      result = tool.call("branch_name" => "derived-branch", "from" => "base-branch")
      expect(result[:success]).to be true
      expect(result[:branch]).to eq("derived-branch")
    end

    it "rejects invalid base branch name" do
      result = tool.call("branch_name" => "good-name", "from" => "bad name!")
      expect(result[:success]).to be false
      expect(result[:error]).to include("Invalid base branch name")
    end

    it "handles git errors gracefully" do
      allow(Open3).to receive(:capture3).and_raise(Errno::ENOENT, "git not found")

      result = tool.call("branch_name" => "test-branch")
      expect(result[:success]).to be false
      expect(result[:error]).to include("Failed to create branch")
    end

    it "returns error when git checkout fails" do
      status = instance_double(Process::Status, exitstatus: 128)
      allow(Open3).to receive(:capture3)
        .and_return(["", "fatal: not a git repository", status])

      result = tool.call("branch_name" => "test-branch")
      expect(result[:success]).to be false
      expect(result[:error]).to include("git checkout failed")
    end

    it "requires confirmation" do
      expect(tool.requires_confirmation?).to be true
    end
  end
end
