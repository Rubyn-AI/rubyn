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

  describe "PATCH /rubyn/refactor (apply)" do
    let(:existing_file) { "app/models/order.rb" }
    let(:new_code) { "# frozen_string_literal: true\n\nclass Order < ApplicationRecord\n  has_many :line_items\nend\n" }

    it "updates an existing file and returns 'Updated'" do
      patch "/rubyn/refactor", params: { file: existing_file, code: new_code }, as: :json

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["success"]).to be true
      expect(json["message"]).to start_with("Updated")

      full_path = Rails.root.join(existing_file)
      expect(File.read(full_path)).to include("has_many :line_items")
    end

    it "creates a new file in a new directory and returns 'Created'" do
      new_file = "app/services/orders/scoring_service.rb"
      full_path = Rails.root.join(new_file)
      FileUtils.rm_f(full_path)

      patch "/rubyn/refactor", params: { file: new_file, code: "class ScoringService\nend\n" }, as: :json

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["success"]).to be true
      expect(json["message"]).to start_with("Created")
      expect(File.exist?(full_path)).to be true
      expect(File.read(full_path)).to include("class ScoringService")
    ensure
      FileUtils.rm_rf(Rails.root.join("app/services/orders"))
    end

    it "returns 400 when file path is missing" do
      patch "/rubyn/refactor", params: { code: new_code }, as: :json

      expect(response).to have_http_status(:bad_request)
    end

    it "returns 400 when code is missing" do
      patch "/rubyn/refactor", params: { file: existing_file }, as: :json

      expect(response).to have_http_status(:bad_request)
    end
  end
end
