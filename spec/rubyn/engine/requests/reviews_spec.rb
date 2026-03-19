# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Code Review", type: :request do
  describe "GET /rubyn/reviews" do
    it "renders the review page with a file param" do
      get "/rubyn/reviews", params: { file: "app/models/order.rb" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Code Review")
      expect(response.body).to include("app/models/order.rb")
    end

    it "renders empty state without a file param" do
      get "/rubyn/reviews"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("file browser")
    end
  end

  describe "POST /rubyn/reviews" do
    let(:file_path) { "app/models/order.rb" }

    before do
      stub_streaming_review(content: "No major issues found. Code follows Rails conventions.")
    end

    it "calls the API and returns review findings" do
      post "/rubyn/reviews", params: { file: file_path }, as: :json

      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body)
      expect(json["response"]).to include("No major issues")
    end

    it "sends the file as a review files array" do
      post "/rubyn/reviews", params: { file: file_path }, as: :json

      expect(WebMock).to have_requested(:post, "https://api.rubyn.dev/api/v1/ai/review")
        .with { |req|
          body = JSON.parse(req.body)
          body["files"].is_a?(Array) && body["files"].first["file_path"] == file_path
        }
    end

    it "returns 404 for missing files" do
      post "/rubyn/reviews", params: { file: "nonexistent/file.rb" }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end
end
