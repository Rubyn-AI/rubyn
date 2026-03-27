# frozen_string_literal: true

RSpec.describe Rubyn::Context::FileApplier do
  let(:tmpdir) { Dir.mktmpdir }
  let(:original_file) { File.join(tmpdir, "app/services/post_analytics_service.rb") }
  let(:formatter) { Rubyn::Output::Formatter }
  let(:applier) { described_class.new(original_file: original_file, formatter: formatter) }

  before do
    FileUtils.mkdir_p(File.dirname(original_file))
    File.write(original_file, "class PostAnalyticsService\nend\n")
  end

  after { FileUtils.rm_rf(tmpdir) }

  describe "#apply with single file block" do
    let(:file_blocks) { [{ path: nil, tag: nil, code: "class PostAnalyticsService\n  def score\n    42\n  end\nend\n" }] }

    it "writes the code to the original file when user confirms" do
      allow($stdin).to receive(:gets).and_return("y\n")
      applier.apply(file_blocks)
      expect(File.read(original_file)).to include("def score")
    end

    it "does not write when user declines" do
      allow($stdin).to receive(:gets).and_return("n\n")
      applier.apply(file_blocks)
      expect(File.read(original_file)).not_to include("def score")
    end

    it "shows diff and applies when user confirms after diff" do
      allow($stdin).to receive(:gets).and_return("diff\n", "y\n")
      allow(Rubyn::Output::DiffRenderer).to receive(:render)
      applier.apply(file_blocks)
      expect(File.read(original_file)).to include("def score")
    end

    it "shows diff and discards when user declines after diff" do
      allow($stdin).to receive(:gets).and_return("diff\n", "n\n")
      allow(Rubyn::Output::DiffRenderer).to receive(:render)
      applier.apply(file_blocks)
      expect(File.read(original_file)).not_to include("def score")
    end
  end

  describe "#apply with multiple file blocks" do
    let(:new_file_path) { "app/services/engagement_scorer.rb" }
    let(:file_blocks) do
      [
        { path: original_file, tag: "updated", code: "class PostAnalyticsService\n  def delegate\n    EngagementScorer.new\n  end\nend\n" },
        { path: new_file_path, tag: "new", code: "class EngagementScorer\n  def compute\n    42\n  end\nend\n" }
      ]
    end

    it "writes all files when user confirms with 'y'" do
      allow($stdin).to receive(:gets).and_return("y\n")
      allow(Dir).to receive(:pwd).and_return(tmpdir)

      applier.apply(file_blocks)

      expect(File.read(original_file)).to include("def delegate")
      new_full_path = File.join(tmpdir, new_file_path)
      expect(File.exist?(new_full_path)).to be true
      expect(File.read(new_full_path)).to include("class EngagementScorer")
    end

    it "creates directories for new files" do
      allow($stdin).to receive(:gets).and_return("y\n")
      allow(Dir).to receive(:pwd).and_return(tmpdir)

      deep_path = "app/services/posts/scoring/engagement_scorer.rb"
      blocks = [{ path: deep_path, tag: "new", code: "class Scorer\nend\n" }]
      applier.apply(blocks)

      expect(File.exist?(File.join(tmpdir, deep_path))).to be true
    end

    it "does not write when user declines" do
      allow($stdin).to receive(:gets).and_return("n\n")
      applier.apply(file_blocks)
      expect(File.read(original_file)).not_to include("def delegate")
    end

    it "applies selected files when user chooses 'select' and 'y'" do
      allow($stdin).to receive(:gets).and_return("select\n", "y\n", "y\n")
      allow(Dir).to receive(:pwd).and_return(tmpdir)

      applier.apply(file_blocks)

      expect(File.read(original_file)).to include("def delegate")
      new_full_path = File.join(tmpdir, new_file_path)
      expect(File.exist?(new_full_path)).to be true
    end

    it "skips files when user chooses 'select' and 'n'" do
      allow($stdin).to receive(:gets).and_return("select\n", "n\n", "n\n")
      allow(Dir).to receive(:pwd).and_return(tmpdir)

      applier.apply(file_blocks)

      expect(File.read(original_file)).not_to include("def delegate")
      new_full_path = File.join(tmpdir, new_file_path)
      expect(File.exist?(new_full_path)).to be false
    end

    it "shows diff for selected file and applies on confirm" do
      allow($stdin).to receive(:gets).and_return("select\n", "diff\n", "y\n", "n\n")
      allow(Dir).to receive(:pwd).and_return(tmpdir)
      allow(Rubyn::Output::DiffRenderer).to receive(:render)

      applier.apply(file_blocks)

      expect(File.read(original_file)).to include("def delegate")
    end

    it "shows diff for selected file and skips on decline" do
      allow($stdin).to receive(:gets).and_return("select\n", "diff\n", "n\n", "n\n")
      allow(Dir).to receive(:pwd).and_return(tmpdir)
      allow(Rubyn::Output::DiffRenderer).to receive(:render)

      applier.apply(file_blocks)

      expect(File.read(original_file)).not_to include("def delegate")
    end
  end
end
