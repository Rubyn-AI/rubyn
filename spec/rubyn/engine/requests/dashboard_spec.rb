# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Dashboard", type: :request do
  before do
    stub_get_balance(balance: 75, plan: "pro")
    stub_get_history
  end

  describe "GET /rubyn" do
    it "renders the dashboard" do
      get "/rubyn"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Dashboard")
    end
  end
end
