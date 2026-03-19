# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Settings", type: :request do
  describe "GET /rubyn/settings" do
    it "renders the settings page" do
      get "/rubyn/settings"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Settings")
      expect(response.body).to include("API Key")
    end

    it "shows configured status when API key exists" do
      allow(Rubyn::Config::Credentials).to receive(:exists?).and_return(true)

      get "/rubyn/settings"

      expect(response.body).to include("Configured")
    end
  end
end
