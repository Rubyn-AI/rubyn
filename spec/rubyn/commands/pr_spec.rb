# frozen_string_literal: true

RSpec.describe Rubyn::Commands::Pr do
  let(:tmpdir) { Dir.mktmpdir }
  let(:command) { described_class.new }

  before do
    stub_const("Rubyn::Config::Credentials::CREDENTIALS_DIR", tmpdir)
    stub_const("Rubyn::Config::Credentials::CREDENTIALS_FILE", File.join(tmpdir, "credentials"))
    Rubyn::Config::Credentials.store(api_key: "rk_test")
    Rubyn::Config::ProjectConfig.write({ "project_token" => "rprj_test", "project_id" => 1 }, tmpdir)
    allow(Dir).to receive(:pwd).and_return(tmpdir)

    allow($stdout).to receive(:write)
    allow($stdout).to receive(:print)

    stub_auth_verify
    stub_streaming_pr_review(content: "pr review findings")
  end

  after do
    FileUtils.rm_rf(tmpdir)
  end

  describe "#execute" do
    context "with changes detected" do
      let(:diff_result) do
        {
          base_branch: "main",
          files: [
            { path: "app/models/post.rb", status: "modified", diff: "@@ -1 +1 @@\n-old\n+new", content: "class Post; end" }
          ],
          summary: "1 file(s) changed: 1 modified"
        }
      end

      before do
        diff_double = instance_double(Rubyn::Git::BranchDiff)
        allow(Rubyn::Git::BranchDiff).to receive(:new).and_return(diff_double)
        allow(diff_double).to receive(:diff).and_return(diff_result)
      end

      it "calls the PR review API" do
        command.execute
        expect(WebMock).to have_requested(:post, "https://api.rubyn.dev/api/v1/ai/pr_review")
      end

      it "sends changed files in the files array" do
        command.execute
        expect(WebMock).to have_requested(:post, "https://api.rubyn.dev/api/v1/ai/pr_review")
          .with { |req| JSON.parse(req.body)["files"].any? { |f| f["file_path"] == "app/models/post.rb" } }
      end

      it "sends diffs with the files" do
        command.execute
        expect(WebMock).to have_requested(:post, "https://api.rubyn.dev/api/v1/ai/pr_review")
          .with { |req| JSON.parse(req.body)["files"].first["diff"].include?("@@") }
      end

      it "sends base_branch" do
        command.execute
        expect(WebMock).to have_requested(:post, "https://api.rubyn.dev/api/v1/ai/pr_review")
          .with { |req| JSON.parse(req.body)["base_branch"] == "main" }
      end
    end

    context "with no changes" do
      before do
        diff_double = instance_double(Rubyn::Git::BranchDiff)
        allow(Rubyn::Git::BranchDiff).to receive(:new).and_return(diff_double)
        allow(diff_double).to receive(:diff).and_return({
          base_branch: "main", files: [], summary: "No changes detected"
        })
      end

      it "does not call the API" do
        command.execute
        expect(WebMock).not_to have_requested(:post, "https://api.rubyn.dev/api/v1/ai/pr_review")
      end

      it "displays a warning" do
        expect(Rubyn::Output::Formatter).to receive(:warning).with(/No changes detected/)
        command.execute
      end
    end

    context "when git error occurs" do
      before do
        diff_double = instance_double(Rubyn::Git::BranchDiff)
        allow(Rubyn::Git::BranchDiff).to receive(:new).and_return(diff_double)
        allow(diff_double).to receive(:diff).and_raise(Rubyn::GitError, "Not a git repository")
      end

      it "displays the error" do
        expect(Rubyn::Output::Formatter).to receive(:error).with("Not a git repository")
        command.execute
      end

      it "does not call the API" do
        command.execute
        expect(WebMock).not_to have_requested(:post, "https://api.rubyn.dev/api/v1/ai/pr_review")
      end
    end

    context "when API error occurs" do
      before do
        diff_double = instance_double(Rubyn::Git::BranchDiff)
        allow(Rubyn::Git::BranchDiff).to receive(:new).and_return(diff_double)
        allow(diff_double).to receive(:diff).and_return({
          base_branch: "main",
          files: [{ path: "a.rb", status: "modified", diff: "diff", content: "code" }],
          summary: "1 file(s) changed"
        })

        stub_request(:post, "https://api.rubyn.dev/api/v1/ai/pr_review")
          .to_return(status: 402, body: { error: "Insufficient credits" }.to_json,
                     headers: { "Content-Type" => "application/json" })
      end

      it "displays the API error" do
        expect(Rubyn::Output::Formatter).to receive(:error).with(/Insufficient credits/)
        command.execute
      end
    end

    context "with deleted files" do
      before do
        diff_double = instance_double(Rubyn::Git::BranchDiff)
        allow(Rubyn::Git::BranchDiff).to receive(:new).and_return(diff_double)
        allow(diff_double).to receive(:diff).and_return({
          base_branch: "main",
          files: [
            { path: "app/models/post.rb", status: "modified", diff: "diff", content: "class Post; end" },
            { path: "app/models/old.rb", status: "deleted", diff: "deleted diff", content: nil }
          ],
          summary: "2 file(s) changed"
        })
      end

      it "excludes deleted files from the files payload" do
        command.execute
        expect(WebMock).to have_requested(:post, "https://api.rubyn.dev/api/v1/ai/pr_review")
          .with { |req|
            files = JSON.parse(req.body)["files"]
            files.none? { |f| f["file_path"] == "app/models/old.rb" } &&
              files.any? { |f| f["file_path"] == "app/models/post.rb" }
          }
      end
    end
  end
end
