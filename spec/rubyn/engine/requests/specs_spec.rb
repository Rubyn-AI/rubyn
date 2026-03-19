# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Spec Generator", type: :request do
  describe "GET /rubyn/specs" do
    it "renders the spec generator page with a file param" do
      get "/rubyn/specs", params: { file: "app/models/order.rb" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Spec Generator")
      expect(response.body).to include("app/models/order.rb")
    end

    it "renders empty state without a file param" do
      get "/rubyn/specs"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("file browser")
    end
  end

  describe "POST /rubyn/specs" do
    let(:file_path) { "app/models/order.rb" }

    before do
      stub_streaming_spec(content: "RSpec.describe ApplicationRecord do\nend")
    end

    it "calls the API and returns generated specs" do
      post "/rubyn/specs", params: { file: file_path }, as: :json

      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body)
      expect(json["response"]).to include("RSpec.describe")
    end

    it "returns 404 for missing files" do
      post "/rubyn/specs", params: { file: "nonexistent/file.rb" }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end
end
