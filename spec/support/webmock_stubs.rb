# frozen_string_literal: true

require "webmock/rspec"

WebMock.disable_net_connect!

module WebmockStubs
  API_BASE = "https://api.rubyn.dev"

  def stub_auth_verify(email: "test@example.com", plan: "free")
    stub_request(:post, "#{API_BASE}/api/v1/auth/verify")
      .to_return(
        status: 200,
        body: { user: { email: email, plan: plan } }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  def stub_auth_verify_failure
    stub_request(:post, "#{API_BASE}/api/v1/auth/verify")
      .to_return(
        status: 401,
        body: { error: "Invalid API key" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  def stub_sync_project(project_id: 1, project_token: "rprj_test123")
    stub_request(:post, "#{API_BASE}/api/v1/projects/sync")
      .to_return(
        status: 200,
        body: { project: { id: project_id, project_token: project_token } }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  def stub_join_project(project_id: 1)
    stub_request(:post, "#{API_BASE}/api/v1/projects/join")
      .to_return(
        status: 200,
        body: { project: { id: project_id, name: "test", role: "member" } }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  def stub_index_project
    stub_request(:post, "#{API_BASE}/api/v1/projects/index")
      .to_return(status: 200, body: { indexed: true }.to_json, headers: { "Content-Type" => "application/json" })
  end

  def stub_get_balance(balance: 100, plan: "free")
    stub_request(:get, "#{API_BASE}/api/v1/usage/balance")
      .to_return(
        status: 200,
        body: { credit_balance: balance, credit_allowance: 50, reset_period: "monthly", resets_at: "2024-02-01" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  def stub_get_history(entries: [])
    stub_request(:get, "#{API_BASE}/api/v1/usage/history")
      .with(query: hash_including({}))
      .to_return(
        status: 200,
        body: { interactions: entries, page: 1, per_page: 25, total_count: entries.size, total_pages: 1 }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  def stub_streaming_refactor(content: "refactored code", credits_used: 2)
    stub_request(:post, "#{API_BASE}/api/v1/ai/refactor")
      .to_return(
        status: 200,
        body: { response: content, credits_used: credits_used, model: "claude-haiku-4-5" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  def stub_streaming_spec(content: "spec code", credits_used: 2)
    stub_request(:post, "#{API_BASE}/api/v1/ai/spec")
      .to_return(
        status: 200,
        body: { response: content, credits_used: credits_used, model: "claude-haiku-4-5" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  def stub_streaming_review(content: "review findings", credits_used: 2)
    stub_request(:post, "#{API_BASE}/api/v1/ai/review")
      .to_return(
        status: 200,
        body: { response: content, credits_used: credits_used, model: "claude-haiku-4-5" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  def stub_streaming_agent(content: "agent response", credits_used: 2, conversation_id: 1)
    stub_request(:post, "#{API_BASE}/api/v1/ai/agent")
      .to_return(
        status: 200,
        body: { type: "text", response: content, credits_used: credits_used,
                conversation_id: conversation_id, model: "claude-haiku-4-5" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  def stub_list_conversations(conversations: [])
    stub_request(:get, "#{API_BASE}/api/v1/conversations")
      .with(query: hash_including({}))
      .to_return(
        status: 200,
        body: conversations.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  def stub_submit_tool_results(content: "tool result response", credits_used: 2, conversation_id: 1)
    stub_request(:post, "#{API_BASE}/api/v1/ai/agent/tool_results")
      .to_return(
        status: 200,
        body: { type: "text", response: content, credits_used: credits_used,
                conversation_id: conversation_id, model: "claude-haiku-4-5" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end
end
