# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Agent", type: :request do
  describe "GET /rubyn/agent" do
    it "is not routed (agent is CLI-only)" do
      expect { get "/rubyn/agent" }.to raise_error(ActionController::RoutingError)
    end
  end
end
