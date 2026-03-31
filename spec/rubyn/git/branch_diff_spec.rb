# frozen_string_literal: true

RSpec.describe Rubyn::Git::BranchDiff do
  let(:tmpdir) { Dir.mktmpdir }
  let(:differ) { described_class.new(tmpdir) }

  before do
    git_init(tmpdir)
  end

  after do
    FileUtils.rm_rf(tmpdir)
  end

  describe "#diff" do
    context "with modified files" do
      before do
        create_and_commit(tmpdir, "app/models/post.rb", "class Post; end")
        git_branch(tmpdir, "feature")
        write_file(tmpdir, "app/models/post.rb", "class Post\n  validates :title\nend")
        git_add_commit(tmpdir, "Update post")
      end

      it "detects modified files" do
        result = differ.diff(base: "main")
        expect(result[:files].size).to eq(1)
        expect(result[:files][0][:path]).to eq("app/models/post.rb")
        expect(result[:files][0][:status]).to eq("modified")
      end

      it "includes file content" do
        result = differ.diff(base: "main")
        expect(result[:files][0][:content]).to include("validates :title")
      end

      it "includes the diff" do
        result = differ.diff(base: "main")
        expect(result[:files][0][:diff]).to include("validates :title")
      end

      it "returns base branch name" do
        result = differ.diff(base: "main")
        expect(result[:base_branch]).to eq("main")
      end

      it "returns a summary" do
        result = differ.diff(base: "main")
        expect(result[:summary]).to include("1 file(s) changed")
        expect(result[:summary]).to include("modified")
      end
    end

    context "with added files" do
      before do
        create_and_commit(tmpdir, "README.md", "# Hello")
        git_branch(tmpdir, "feature")
        create_and_commit(tmpdir, "app/services/foo.rb", "class Foo; end")
      end

      it "detects added files" do
        result = differ.diff(base: "main")
        added = result[:files].find { |f| f[:path] == "app/services/foo.rb" }
        expect(added[:status]).to eq("added")
        expect(added[:content]).to eq("class Foo; end")
      end
    end

    context "with deleted files" do
      before do
        create_and_commit(tmpdir, "app/models/old.rb", "class Old; end")
        git_branch(tmpdir, "feature")
        File.delete(File.join(tmpdir, "app/models/old.rb"))
        git_add_commit(tmpdir, "Remove old model")
      end

      it "detects deleted files with nil content" do
        result = differ.diff(base: "main")
        deleted = result[:files].find { |f| f[:path] == "app/models/old.rb" }
        expect(deleted[:status]).to eq("deleted")
        expect(deleted[:content]).to be_nil
      end
    end

    context "with no changes" do
      before do
        create_and_commit(tmpdir, "README.md", "# Hello")
      end

      it "returns empty files list" do
        result = differ.diff(base: "main")
        expect(result[:files]).to be_empty
      end

      it "returns 'No changes detected' summary" do
        result = differ.diff(base: "main")
        expect(result[:summary]).to eq("No changes detected")
      end
    end

    context "with uncommitted changes on main" do
      before do
        create_and_commit(tmpdir, "app/models/post.rb", "class Post; end")
        write_file(tmpdir, "app/models/post.rb", "class Post\n  # changed\nend")
      end

      it "detects unstaged changes against HEAD" do
        result = differ.diff
        expect(result[:files].size).to eq(1)
        expect(result[:files][0][:path]).to eq("app/models/post.rb")
      end
    end

    context "with staged but uncommitted changes" do
      before do
        create_and_commit(tmpdir, "app/models/post.rb", "class Post; end")
        write_file(tmpdir, "app/models/post.rb", "class Post\n  # staged\nend")
        run_in(tmpdir, "git", "add", "app/models/post.rb")
      end

      it "detects staged changes" do
        result = differ.diff
        expect(result[:files].size).to eq(1)
        expect(result[:files][0][:content]).to include("# staged")
      end
    end

    context "base branch auto-detection" do
      before do
        create_and_commit(tmpdir, "README.md", "# Hello")
      end

      it "auto-detects main branch" do
        result = differ.diff
        expect(result[:base_branch]).to eq("main")
      end
    end

    context "with explicit base branch" do
      before do
        create_and_commit(tmpdir, "README.md", "# Hello")
        git_branch(tmpdir, "develop")
        create_and_commit(tmpdir, "new.rb", "# new")
      end

      it "uses the specified base branch" do
        result = differ.diff(base: "main")
        expect(result[:base_branch]).to eq("main")
      end
    end

    context "when base branch does not exist" do
      before do
        create_and_commit(tmpdir, "README.md", "# Hello")
      end

      it "raises GitError for explicit nonexistent branch" do
        expect { differ.diff(base: "nonexistent") }.to raise_error(Rubyn::GitError, /not found/)
      end
    end

    context "when not in a git repo" do
      let(:non_git_dir) { Dir.mktmpdir }
      let(:differ) { described_class.new(non_git_dir) }

      after { FileUtils.rm_rf(non_git_dir) }

      it "raises GitError" do
        expect { differ.diff }.to raise_error(Rubyn::GitError, /Not a git repository/)
      end
    end

    context "with large diffs" do
      before do
        large_content = "x = 1\n" * 5000
        create_and_commit(tmpdir, "big.rb", "# empty")
        git_branch(tmpdir, "feature")
        write_file(tmpdir, "big.rb", large_content)
        git_add_commit(tmpdir, "Large change")
      end

      it "truncates diffs exceeding the limit" do
        result = differ.diff(base: "main")
        big = result[:files].find { |f| f[:path] == "big.rb" }
        expect(big[:diff].bytesize).to be <= Rubyn::Git::BranchDiff::MAX_DIFF_BYTES + 200
      end
    end
  end

  # Helper methods for git operations in tmpdir
  def git_init(dir)
    run_in(dir, "git", "init")
    run_in(dir, "git", "checkout", "-b", "main")
    run_in(dir, "git", "config", "user.email", "test@example.com")
    run_in(dir, "git", "config", "user.name", "Test")
  end

  def create_and_commit(dir, path, content)
    write_file(dir, path, content)
    git_add_commit(dir, "Add #{path}")
  end

  def write_file(dir, path, content)
    full = File.join(dir, path)
    FileUtils.mkdir_p(File.dirname(full))
    File.write(full, content)
  end

  def git_add_commit(dir, message)
    run_in(dir, "git", "add", "-A")
    run_in(dir, "git", "commit", "-m", message)
  end

  def git_branch(dir, name)
    run_in(dir, "git", "checkout", "-b", name)
  end

  def run_in(dir, *cmd)
    Open3.capture3(*cmd, chdir: dir)
  end
end
