# frozen_string_literal: true

RSpec.describe "File tools" do
  let(:tmpdir) { Dir.mktmpdir }

  after do
    FileUtils.rm_rf(tmpdir)
  end

  describe Rubyn::Tools::ReadFile do
    let(:tool) { described_class.new(tmpdir) }

    before do
      File.write(File.join(tmpdir, "sample.rb"), "line1\nline2\nline3\nline4\nline5\n")
    end

    it "reads a file" do
      result = tool.call("path" => "sample.rb")
      expect(result[:success]).to be true
      expect(result[:content]).to include("line1")
      expect(result[:line_count]).to eq(5)
    end

    it "reads a line range" do
      result = tool.call("path" => "sample.rb", "line_start" => 2, "line_end" => 3)
      expect(result[:success]).to be true
      expect(result[:content]).to include("line2")
      expect(result[:content]).to include("line3")
      expect(result[:content]).not_to include("line1")
    end

    it "returns error for non-existent file" do
      result = tool.call("path" => "missing.rb")
      expect(result[:success]).to be false
    end

    it "blocks path traversal" do
      result = tool.call("path" => "../../etc/passwd")
      expect(result[:success]).to be false
      expect(result[:error]).to include("outside project")
    end

    it "does not require confirmation" do
      expect(tool.requires_confirmation?).to be false
    end
  end

  describe Rubyn::Tools::WriteFile do
    let(:tool) { described_class.new(tmpdir) }

    it "writes content to a file" do
      result = tool.call("path" => "output.rb", "content" => "hello world")
      expect(result[:success]).to be true
      expect(File.read(File.join(tmpdir, "output.rb"))).to eq("hello world")
    end

    it "creates parent directories" do
      result = tool.call("path" => "deep/nested/file.rb", "content" => "code")
      expect(result[:success]).to be true
      expect(File.exist?(File.join(tmpdir, "deep/nested/file.rb"))).to be true
    end

    it "requires confirmation" do
      expect(tool.requires_confirmation?).to be true
    end
  end

  describe Rubyn::Tools::CreateFile do
    let(:tool) { described_class.new(tmpdir) }

    it "creates a new file" do
      result = tool.call("path" => "new.rb", "content" => "new content")
      expect(result[:success]).to be true
      expect(File.read(File.join(tmpdir, "new.rb"))).to eq("new content")
    end

    it "fails if file already exists" do
      File.write(File.join(tmpdir, "existing.rb"), "old")
      result = tool.call("path" => "existing.rb", "content" => "new")
      expect(result[:success]).to be false
      expect(result[:error]).to include("already exists")
    end
  end

  describe Rubyn::Tools::PatchFile do
    let(:tool) { described_class.new(tmpdir) }

    before do
      File.write(File.join(tmpdir, "target.rb"), "foo bar foo baz")
    end

    it "replaces first occurrence" do
      result = tool.call("path" => "target.rb", "find" => "foo", "replace" => "qux")
      expect(result[:success]).to be true
      expect(result[:replacements]).to eq(1)
      expect(File.read(File.join(tmpdir, "target.rb"))).to eq("qux bar foo baz")
    end

    it "replaces all occurrences when requested" do
      result = tool.call("path" => "target.rb", "find" => "foo", "replace" => "qux", "all_occurrences" => true)
      expect(result[:success]).to be true
      expect(result[:replacements]).to eq(2)
      expect(File.read(File.join(tmpdir, "target.rb"))).to eq("qux bar qux baz")
    end

    it "returns error when pattern not found" do
      result = tool.call("path" => "target.rb", "find" => "missing", "replace" => "x")
      expect(result[:success]).to be false
    end
  end

  describe Rubyn::Tools::DeleteFile do
    let(:tool) { described_class.new(tmpdir) }

    it "deletes a file" do
      path = File.join(tmpdir, "doomed.rb")
      File.write(path, "bye")
      result = tool.call("path" => "doomed.rb")
      expect(result[:success]).to be true
      expect(File.exist?(path)).to be false
    end

    it "returns error for non-existent file" do
      result = tool.call("path" => "ghost.rb")
      expect(result[:success]).to be false
    end
  end

  describe Rubyn::Tools::MoveFile do
    let(:tool) { described_class.new(tmpdir) }

    before do
      File.write(File.join(tmpdir, "original.rb"), "content")
    end

    it "moves a file" do
      result = tool.call("source" => "original.rb", "destination" => "renamed.rb")
      expect(result[:success]).to be true
      expect(File.exist?(File.join(tmpdir, "renamed.rb"))).to be true
      expect(File.exist?(File.join(tmpdir, "original.rb"))).to be false
    end

    it "creates destination directories" do
      result = tool.call("source" => "original.rb", "destination" => "subdir/moved.rb")
      expect(result[:success]).to be true
      expect(File.exist?(File.join(tmpdir, "subdir/moved.rb"))).to be true
    end

    it "returns error if source doesn't exist" do
      result = tool.call("source" => "nope.rb", "destination" => "dest.rb")
      expect(result[:success]).to be false
    end
  end
end
