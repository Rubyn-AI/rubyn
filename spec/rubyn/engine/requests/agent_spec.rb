# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Agent", type: :request do
  before do
    stub_list_conversations(conversations: [])
  end

  describe "GET /rubyn/agent" do
    it "renders the agent chat page" do
      get "/rubyn/agent"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Agent")
      expect(response.body).to include("chat-form")
    end
  end

  describe "POST /rubyn/agent" do
    before do
      stub_streaming_agent(content: "Hello! How can I help?", conversation_id: 1)
    end

    it "sends a message and returns JSON response" do
      post "/rubyn/agent", params: { message: "hello" }, as: :json

      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body)
      expect(json["type"]).to eq("text")
      expect(json["response"]).to eq("Hello! How can I help?")
      expect(json["conversation_id"]).to eq(1)
    end

    it "passes conversation_id for follow-up messages" do
      post "/rubyn/agent", params: { message: "and this?", conversation_id: 1 }, as: :json

      expect(response).to have_http_status(:ok)
      expect(WebMock).to have_requested(:post, "https://api.rubyn.dev/api/v1/ai/agent")
    end

    it "returns error on API failure" do
      stub_request(:post, "https://api.rubyn.dev/api/v1/ai/agent")
        .to_return(status: 422, body: { error: "Insufficient credits" }.to_json,
                   headers: { "Content-Type" => "application/json" })

      post "/rubyn/agent", params: { message: "hello" }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json["error"]).to include("Insufficient credits")
    end
  end
end
