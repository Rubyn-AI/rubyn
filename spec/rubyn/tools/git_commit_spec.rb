# frozen_string_literal: true

require "open3"

RSpec.describe Rubyn::Tools::GitCommit do
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
    it "requires message parameter" do
      result = tool.call({})
      expect(result[:success]).to be false
      expect(result[:error]).to include("message is required")
    end

    it "rejects empty message" do
      result = tool.call("message" => "  ")
      expect(result[:success]).to be false
      expect(result[:error]).to include("message is required")
    end

    it "commits all changes with git add -A when no files specified" do
      File.write(File.join(tmpdir, "new_file.rb"), "# new")
      result = tool.call("message" => "add new file")
      expect(result[:success]).to be true
      expect(result[:message]).to eq("add new file")
      expect(result[:hash]).to match(/\A[a-f0-9]+\z/)
    end

    it "commits specific files when files array is provided" do
      File.write(File.join(tmpdir, "a.rb"), "# a")
      File.write(File.join(tmpdir, "b.rb"), "# b")
      result = tool.call("message" => "add a only", "files" => ["a.rb"])
      expect(result[:success]).to be true

      # Verify b.rb is not committed (still untracked)
      git_status = `git -C #{tmpdir} status --porcelain`.strip
      expect(git_status).to include("b.rb")
    end

    it "handles git add failure" do
      add_status = instance_double(Process::Status, exitstatus: 1)
      allow(Open3).to receive(:capture3)
        .with("git add -A", chdir: tmpdir)
        .and_return(["", "fatal: error", add_status])

      result = tool.call("message" => "test commit")
      expect(result[:success]).to be false
      expect(result[:error]).to include("git add failed")
    end

    it "handles git commit failure" do
      File.write(File.join(tmpdir, "change.rb"), "# change")

      add_status = instance_double(Process::Status, exitstatus: 0)
      commit_status = instance_double(Process::Status, exitstatus: 1)
      allow(Open3).to receive(:capture3)
        .with("git add -A", chdir: tmpdir)
        .and_return(["", "", add_status])
      allow(Open3).to receive(:capture3)
        .with("git", "commit", "-m", "test commit", chdir: tmpdir)
        .and_return(["", "nothing to commit", commit_status])

      result = tool.call("message" => "test commit")
      expect(result[:success]).to be false
      expect(result[:error]).to include("git commit failed")
    end

    it "handles Open3 exception during add" do
      allow(Open3).to receive(:capture3)
        .with("git add -A", chdir: tmpdir)
        .and_raise(Errno::ENOENT, "git not found")

      result = tool.call("message" => "test")
      expect(result[:success]).to be false
      expect(result[:error]).to include("Failed to stage files")
    end

    it "handles Open3 exception during commit" do
      add_status = instance_double(Process::Status, exitstatus: 0)
      allow(Open3).to receive(:capture3)
        .with("git add -A", chdir: tmpdir)
        .and_return(["", "", add_status])
      allow(Open3).to receive(:capture3)
        .with("git", "commit", "-m", "test", chdir: tmpdir)
        .and_raise(Errno::ENOENT, "git not found")

      result = tool.call("message" => "test")
      expect(result[:success]).to be false
      expect(result[:error]).to include("Failed to create commit")
    end

    it "extracts commit hash from output" do
      File.write(File.join(tmpdir, "file.rb"), "# content")
      result = tool.call("message" => "test commit hash")
      expect(result[:hash]).not_to eq("unknown")
      expect(result[:hash]).to match(/\A[a-f0-9]+\z/)
    end

    it "returns unknown when commit hash cannot be parsed" do
      File.write(File.join(tmpdir, "file.rb"), "# content")

      add_status = instance_double(Process::Status, exitstatus: 0)
      commit_status = instance_double(Process::Status, exitstatus: 0)
      allow(Open3).to receive(:capture3)
        .with(start_with("git add"), chdir: tmpdir)
        .and_return(["", "", add_status])
      allow(Open3).to receive(:capture3)
        .with("git", "commit", "-m", "test", chdir: tmpdir)
        .and_return(["unexpected output format", "", commit_status])

      result = tool.call("message" => "test")
      expect(result[:hash]).to eq("unknown")
    end

    it "requires confirmation" do
      expect(tool.requires_confirmation?).to be true
    end
  end
end
