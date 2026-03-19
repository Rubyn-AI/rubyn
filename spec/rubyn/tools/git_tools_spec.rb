# frozen_string_literal: true

RSpec.describe "Git tools" do
  let(:tmpdir) { Dir.mktmpdir }

  before do
    system("git init #{tmpdir}", out: File::NULL, err: File::NULL)
    system("git -C #{tmpdir} config user.email 'test@test.com'", out: File::NULL, err: File::NULL)
    system("git -C #{tmpdir} config user.name 'Test'", out: File::NULL, err: File::NULL)
    File.write(File.join(tmpdir, "initial.rb"), "# initial")
    system("git -C #{tmpdir} add . && git -C #{tmpdir} commit -m 'initial'", out: File::NULL, err: File::NULL)
  end

  after do
    FileUtils.rm_rf(tmpdir)
  end

  describe Rubyn::Tools::GitStatus do
    let(:tool) { described_class.new(tmpdir) }

    it "shows clean status" do
      result = tool.call({})
      expect(result[:success]).to be true
      expect(result[:clean]).to be true
    end

    it "shows dirty status" do
      File.write(File.join(tmpdir, "new.rb"), "change")
      result = tool.call({})
      expect(result[:success]).to be true
      expect(result[:clean]).to be false
      expect(result[:status]).to include("new.rb")
    end

    it "does not require confirmation" do
      expect(tool.requires_confirmation?).to be false
    end
  end

  describe Rubyn::Tools::GitDiff do
    let(:tool) { described_class.new(tmpdir) }

    it "shows diff of changes" do
      File.write(File.join(tmpdir, "initial.rb"), "# modified")
      result = tool.call({})
      expect(result[:success]).to be true
      expect(result[:diff]).to include("modified")
    end

    it "shows staged diff" do
      File.write(File.join(tmpdir, "initial.rb"), "# staged")
      system("git -C #{tmpdir} add .", out: File::NULL, err: File::NULL)
      result = tool.call("staged" => true)
      expect(result[:success]).to be true
      expect(result[:diff]).to include("staged")
    end
  end

  describe Rubyn::Tools::GitLog do
    let(:tool) { described_class.new(tmpdir) }

    it "shows commit history" do
      result = tool.call({})
      expect(result[:success]).to be true
      expect(result[:commits].size).to be >= 1
      expect(result[:commits].first).to have_key(:hash)
      expect(result[:commits].first).to have_key(:message)
    end

    it "limits number of commits" do
      result = tool.call("count" => 1)
      expect(result[:commits].size).to eq(1)
    end
  end

  describe Rubyn::Tools::GitCommit do
    let(:tool) { described_class.new(tmpdir) }

    it "commits changes" do
      File.write(File.join(tmpdir, "new.rb"), "new file")
      result = tool.call("message" => "add new file", "files" => ["new.rb"])
      expect(result[:success]).to be true
      expect(result[:message]).to include("add new file")
    end

    it "requires confirmation" do
      expect(tool.requires_confirmation?).to be true
    end
  end

  describe Rubyn::Tools::GitCreateBranch do
    let(:tool) { described_class.new(tmpdir) }

    it "creates a new branch" do
      result = tool.call("branch_name" => "feature/test")
      expect(result[:success]).to be true
      expect(result[:branch]).to eq("feature/test")
    end

    it "rejects invalid branch names" do
      result = tool.call("branch_name" => "bad branch name")
      expect(result[:success]).to be false
    end

    it "requires confirmation" do
      expect(tool.requires_confirmation?).to be true
    end
  end
end
