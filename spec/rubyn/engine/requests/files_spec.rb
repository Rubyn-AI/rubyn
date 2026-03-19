# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Files", type: :request do
  describe "GET /rubyn/files" do
    it "renders the file browser" do
      get "/rubyn/files"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Project Files")
    end

    it "groups files into categories" do
      get "/rubyn/files"

      expect(response.body).to include("categories")
    end
  end
end
