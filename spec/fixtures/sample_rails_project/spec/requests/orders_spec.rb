require "rails_helper"

RSpec.describe "Orders", type: :request do
  describe "GET /orders" do
    it "returns success" do
      get orders_path
      expect(response).to have_http_status(:ok)
    end
  end
end
