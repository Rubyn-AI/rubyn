# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Refactor", type: :request do
  describe "GET /rubyn/refactor" do
    it "renders the refactor page with a file param" do
      get "/rubyn/refactor", params: { file: "app/models/order.rb" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Refactor")
      expect(response.body).to include("app/models/order.rb")
    end

    it "renders empty state without a file param" do
      get "/rubyn/refactor"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("file browser")
    end
  end

  describe "POST /rubyn/refactor" do
    let(:file_path) { "app/models/order.rb" }

    before do
      stub_streaming_refactor(content: "# Refactored\nclass ApplicationRecord; end")
    end

    it "calls the API and returns the refactored code" do
      post "/rubyn/refactor", params: { file: file_path }, as: :json

      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body)
      expect(json["response"]).to include("Refactored")
      expect(json["credits_used"]).to eq(2)
    end

    it "sends context_files to the API" do
      post "/rubyn/refactor", params: { file: file_path }, as: :json

      expect(WebMock).to have_requested(:post, "https://api.rubyn.dev/api/v1/ai/refactor")
        .with { |req| JSON.parse(req.body).key?("context_files") }
    end

    it "returns 404 for missing files" do
      post "/rubyn/refactor", params: { file: "nonexistent/file.rb" }, as: :json

      expect(response).to have_http_status(:not_found)
    end

    it "returns error on API failure" do
      stub_request(:post, "https://api.rubyn.dev/api/v1/ai/refactor")
        .to_return(status: 422, body: { error: "Insufficient credits" }.to_json,
                   headers: { "Content-Type" => "application/json" })

      post "/rubyn/refactor", params: { file: file_path }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
