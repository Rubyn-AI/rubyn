# frozen_string_literal: true

RSpec.describe Rubyn::Client::ApiClient do
  let(:api_client) { described_class.new(base_url: "https://api.rubyn.dev", api_key: "rk_test") }

  before do
    allow_any_instance_of(described_class).to receive(:sleep)
  end

  describe "post_with_recovery" do
    context "when the request succeeds" do
      before do
        stub_request(:post, "https://api.rubyn.dev/api/v1/ai/refactor")
          .to_return(status: 200, body: { response: "refactored", credits_used: 2 }.to_json,
                     headers: { "Content-Type" => "application/json" })
      end

      it "returns the response normally" do
        result = api_client.refactor(
          file_path: "app/models/user.rb",
          code: "class User; end",
          context_files: [],
          project_token: "rprj_test"
        )
        expect(result["response"]).to eq("refactored")
      end

      it "sends a request_uuid in the body" do
        api_client.refactor(
          file_path: "app/models/user.rb",
          code: "class User; end",
          context_files: [],
          project_token: "rprj_test"
        )

        expect(WebMock).to have_requested(:post, "https://api.rubyn.dev/api/v1/ai/refactor")
          .with { |req| JSON.parse(req.body).key?("request_uuid") }
      end
    end

    context "when the request times out" do
      before do
        stub_request(:post, "https://api.rubyn.dev/api/v1/ai/refactor")
          .to_raise(Faraday::TimeoutError.new("request timed out"))
      end

      it "polls the interaction endpoint and recovers the response" do
        stub_request(:get, %r{api.rubyn.dev/api/v1/ai/interactions/.+})
          .to_return(status: 200, body: { response: "recovered refactor", credits_used: 2 }.to_json,
                     headers: { "Content-Type" => "application/json" })

        result = api_client.refactor(
          file_path: "app/models/user.rb",
          code: "class User; end",
          context_files: [],
          project_token: "rprj_test"
        )

        expect(result["response"]).to eq("recovered refactor")
      end

      it "raises APIError when recovery fails" do
        stub_request(:get, %r{api.rubyn.dev/api/v1/ai/interactions/.+})
          .to_return(status: 404, body: { error: "Interaction not found" }.to_json,
                     headers: { "Content-Type" => "application/json" })

        expect {
          api_client.refactor(
            file_path: "app/models/user.rb",
            code: "class User; end",
            context_files: [],
            project_token: "rprj_test"
          )
        }.to raise_error(Rubyn::APIError, /timed out/)
      end
    end

    context "when the connection fails" do
      before do
        stub_request(:post, "https://api.rubyn.dev/api/v1/ai/refactor")
          .to_raise(Faraday::ConnectionFailed.new("connection refused"))
      end

      it "raises APIError without attempting recovery" do
        expect {
          api_client.refactor(
            file_path: "app/models/user.rb",
            code: "class User; end",
            context_files: [],
            project_token: "rprj_test"
          )
        }.to raise_error(Rubyn::APIError, /Could not connect/)
      end
    end
  end
end
