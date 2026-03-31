# frozen_string_literal: true

require "rails_helper"

RSpec.describe "PR Review", type: :request do
  describe "GET /rubyn/pr_reviews" do
    it "renders the PR review page" do
      allow(Rubyn::Git::BranchDiff).to receive(:new).and_return(
        instance_double(Rubyn::Git::BranchDiff, diff: {
          base_branch: "main",
          files: [{ path: "app/models/order.rb", status: "modified" }],
          summary: "1 file(s) changed"
        })
      )

      get "/rubyn/pr_reviews"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("PR Review")
    end

    it "shows error when not a git repo" do
      allow(Rubyn::Git::BranchDiff).to receive(:new).and_return(
        instance_double(Rubyn::Git::BranchDiff).tap do |d|
          allow(d).to receive(:diff).and_raise(Rubyn::GitError, "Not a git repository")
        end
      )

      get "/rubyn/pr_reviews"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Not a git repository")
    end
  end

  describe "POST /rubyn/pr_reviews" do
    before do
      stub_streaming_pr_review(content: "PR looks good. Minor suggestions below.")
    end

    it "calls the API and returns JSON" do
      allow(Rubyn::Git::BranchDiff).to receive(:new).and_return(
        instance_double(Rubyn::Git::BranchDiff, diff: {
          base_branch: "main",
          files: [{ path: "app/models/order.rb", status: "modified", diff: "@@ diff", content: "class Order; end" }],
          summary: "1 file(s) changed"
        })
      )

      post "/rubyn/pr_reviews", as: :json

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["response"]).to include("PR looks good")
    end

    it "returns error when no changes detected" do
      allow(Rubyn::Git::BranchDiff).to receive(:new).and_return(
        instance_double(Rubyn::Git::BranchDiff, diff: {
          base_branch: "main", files: [], summary: "No changes detected"
        })
      )

      post "/rubyn/pr_reviews", as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json["error"]).to include("No changes")
    end

    it "returns error on git failure" do
      allow(Rubyn::Git::BranchDiff).to receive(:new).and_return(
        instance_double(Rubyn::Git::BranchDiff).tap do |d|
          allow(d).to receive(:diff).and_raise(Rubyn::GitError, "Not a git repository")
        end
      )

      post "/rubyn/pr_reviews", as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json["error"]).to include("Not a git repository")
    end
  end
end
