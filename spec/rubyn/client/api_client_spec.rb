# frozen_string_literal: true

RSpec.describe Rubyn::Client::ApiClient do
  let(:client) { described_class.new(api_key: "rk_test123") }

  before do
    Rubyn.configuration.api_url = "https://api.rubyn.dev"
  end

  describe "#verify_auth" do
    it "sends POST to /api/v1/auth/verify" do
      stub_auth_verify
      result = client.verify_auth
      expect(result.dig("user", "email")).to eq("test@example.com")
    end

    it "raises AuthenticationError on 401" do
      stub_auth_verify_failure
      expect { client.verify_auth }.to raise_error(Rubyn::AuthenticationError)
    end
  end

  describe "#sync_project" do
    it "sends project metadata and returns project info" do
      stub_sync_project
      result = client.sync_project(metadata: { project_name: "test" }, project_token: "rprj_test123")
      expect(result.dig("project", "id")).to eq(1)
      expect(result.dig("project", "project_token")).to eq("rprj_test123")
    end
  end

  describe "#join_project" do
    it "joins an existing project with token" do
      stub_join_project
      result = client.join_project(project_token: "rprj_test123")
      expect(result.dig("project", "id")).to eq(1)
      expect(result.dig("project", "role")).to eq("member")
    end
  end

  describe "#index_project" do
    it "sends files to the API" do
      stub_index_project
      result = client.index_project(project_token: "rprj_test123", files: [{ file_path: "test.rb", content: "code", file_hash: "abc123" }])
      expect(result["indexed"]).to be true
    end
  end

  describe "#get_balance" do
    it "returns credit balance" do
      stub_get_balance(balance: 50, plan: "pro")
      result = client.get_balance
      expect(result["credit_balance"]).to eq(50)
    end
  end

  describe "#get_history" do
    it "returns usage history" do
      stub_get_history(entries: [{ command: "refactor", credits_charged: 2 }])
      result = client.get_history(page: 1)
      expect(result["interactions"].size).to eq(1)
    end
  end

  describe "#refactor" do
    it "returns refactored content" do
      stub_streaming_refactor(content: "new code")

      result = client.refactor(
        file_path: "app/models/order.rb",
        code: "class Order; end",
        context_files: [],
        project_token: "rprj_test123"
      )

      expect(result["response"]).to eq("new code")
      expect(result["credits_used"]).to eq(2)
    end
  end

  describe "#generate_spec" do
    it "returns generated spec content" do
      stub_streaming_spec(content: "describe Order do; end")
      result = client.generate_spec(
        file_path: "app/models/order.rb",
        code: "class Order; end",
        context_files: [],
        project_token: "rprj_test123"
      )

      expect(result["response"]).to eq("describe Order do; end")
    end
  end

  describe "#review" do
    it "returns review findings" do
      stub_streaming_review(content: "No issues found")
      result = client.review(
        files: [{ file_path: "app/models/order.rb", code: "class Order; end" }],
        context_files: [],
        project_token: "rprj_test123"
      )

      expect(result["response"]).to eq("No issues found")
    end
  end

  describe "#agent_message" do
    it "returns agent response" do
      stub_streaming_agent(content: "Hello!")
      result = client.agent_message(
        conversation_id: nil,
        message: "Hi",
        file_context: {},
        project_token: "rprj_test123"
      )

      expect(result["response"]).to eq("Hello!")
      expect(result["type"]).to eq("text")
    end
  end

  describe "#submit_tool_results" do
    it "sends tool results and returns response" do
      stub_submit_tool_results(content: "I've updated the file.")
      result = client.submit_tool_results(
        conversation_id: "conv_123",
        tool_results: [{ tool_call_id: "tc_1", result: { success: true, content: "file contents" } }],
        project_token: "rprj_test123"
      )

      expect(result["response"]).to eq("I've updated the file.")
    end
  end

  describe "error handling" do
    it "raises APIError on 429" do
      stub_request(:get, "https://api.rubyn.dev/api/v1/usage/balance")
        .to_return(status: 429, body: "Rate limited")

      expect { client.get_balance }.to raise_error(Rubyn::APIError, /Rate limit/)
    end

    it "raises APIError on 500" do
      stub_request(:get, "https://api.rubyn.dev/api/v1/usage/balance")
        .to_return(status: 500, body: "Internal server error")

      expect { client.get_balance }.to raise_error(Rubyn::APIError)
    end
  end
end
