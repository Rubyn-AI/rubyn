# frozen_string_literal: true

RSpec.describe Rubyn::Commands::Agent do
  let(:tmpdir) { Dir.mktmpdir }
  let(:command) { described_class.new }
  let(:formatter) { Rubyn::Output::Formatter }

  before do
    stub_const("Rubyn::Config::Credentials::CREDENTIALS_DIR", tmpdir)
    stub_const("Rubyn::Config::Credentials::CREDENTIALS_FILE", File.join(tmpdir, "credentials"))
    Rubyn::Config::Credentials.store(api_key: "rk_test")
    Rubyn::Config::ProjectConfig.write({ "project_token" => "rprj_test", "project_id" => 1 }, tmpdir)
    allow(Dir).to receive(:pwd).and_return(tmpdir)

    allow($stdout).to receive(:write)
    allow($stdout).to receive(:print)

    stub_auth_verify
    stub_streaming_agent(content: "agent response")
  end

  after do
    FileUtils.rm_rf(tmpdir)
  end

  describe "#execute" do
    it "processes messages and exits on /quit" do
      allow($stdin).to receive(:gets).and_return("Hello\n", "/quit\n")
      command.execute
      expect(WebMock).to have_requested(:post, "https://api.rubyn.dev/api/v1/ai/agent")
    end

    it "exits on nil input (EOF)" do
      allow($stdin).to receive(:gets).and_return(nil)
      command.execute
    end

    it "exits on 'exit' command" do
      allow($stdin).to receive(:gets).and_return("exit\n")
      command.execute
    end

    it "skips empty input" do
      allow($stdin).to receive(:gets).and_return("\n", "Hello\n", "/quit\n")
      command.execute
      # Only one API call for "Hello", not for empty line
      expect(WebMock).to have_requested(:post, "https://api.rubyn.dev/api/v1/ai/agent").once
    end

    it "handles /credits command" do
      stub_get_balance(balance: 50, plan: "pro")
      allow($stdin).to receive(:gets).and_return("/credits\n", "/quit\n")
      command.execute
      expect(WebMock).to have_requested(:get, "https://api.rubyn.dev/api/v1/usage/balance")
    end

    it "handles /credits error" do
      allow(Rubyn.api_client).to receive(:get_balance).and_raise(Rubyn::Error, "Network error")
      allow($stdin).to receive(:gets).and_return("/credits\n", "/quit\n")
      expect(formatter).to receive(:error).with("Network error")
      command.execute
    end

    it "handles /new command" do
      allow($stdin).to receive(:gets).and_return("/new\n", "/quit\n")
      expect { command.execute }.not_to raise_error
    end

    it "handles AuthenticationError from agent_message" do
      allow(Rubyn.api_client).to receive(:agent_message).and_raise(Rubyn::AuthenticationError, "Bad key")
      allow($stdin).to receive(:gets).and_return("Hello\n", "/quit\n")
      expect(formatter).to receive(:error).with("Authentication failed: Bad key")
      command.execute
    end

    it "handles APIError from agent_message" do
      allow(Rubyn.api_client).to receive(:agent_message).and_raise(Rubyn::APIError, "Rate limited")
      allow($stdin).to receive(:gets).and_return("Hello\n", "/quit\n")
      expect(formatter).to receive(:error).with("Rate limited")
      command.execute
    end

    it "handles tool_calls response and processes tool loop" do
      tool_call_response = {
        "type" => "tool_calls",
        "conversation_id" => 1,
        "credits_used" => 2,
        "tool_calls" => [
          {
            "id" => "tc_1",
            "name" => "read_file",
            "input" => { "path" => "test.rb" },
            "requires_confirmation" => false
          }
        ]
      }

      # Create a file so the tool can read it
      File.write(File.join(tmpdir, "test.rb"), "puts 'hello'")

      allow(Rubyn.api_client).to receive(:agent_message).and_return(tool_call_response)
      stub_submit_tool_results(content: "Here is the file content", credits_used: 1)

      allow($stdin).to receive(:gets).and_return("Read test.rb\n", "/quit\n")
      command.execute

      expect(WebMock).to have_requested(:post, "https://api.rubyn.dev/api/v1/ai/agent/tool_results")
    end

    it "handles tool_calls with denied_by_user result" do
      tool_call_response = {
        "type" => "tool_calls",
        "conversation_id" => 1,
        "credits_used" => 1,
        "tool_calls" => [
          {
            "id" => "tc_1",
            "name" => "write_file",
            "input" => { "path" => "out.rb", "content" => "code" },
            "requires_confirmation" => true
          }
        ]
      }

      allow(Rubyn.api_client).to receive(:agent_message).and_return(tool_call_response)
      # User denies the tool call, then gets a text response back
      allow($stdin).to receive(:gets).and_return("Write something\n", "n\n", "/quit\n")
      stub_submit_tool_results(content: "Understood, skipping.")

      command.execute
    end

    it "handles tool execution error" do
      tool_call_response = {
        "type" => "tool_calls",
        "conversation_id" => 1,
        "tool_calls" => [
          {
            "id" => "tc_1",
            "name" => "read_file",
            "input" => { "path" => "nonexistent.rb" }
          }
        ]
      }

      allow(Rubyn.api_client).to receive(:agent_message).and_return(tool_call_response)
      stub_submit_tool_results(content: "File not found")

      allow($stdin).to receive(:gets).and_return("Read missing\n", "/quit\n")
      command.execute
    end

    it "stops after MAX_TOOL_ROUNDS" do
      stub_const("Rubyn::Commands::Agent::MAX_TOOL_ROUNDS", 0)

      tool_call_response = {
        "type" => "tool_calls",
        "conversation_id" => 1,
        "tool_calls" => [{ "id" => "tc_1", "name" => "read_file", "input" => { "path" => "x.rb" } }]
      }

      allow(Rubyn.api_client).to receive(:agent_message).and_return(tool_call_response)
      allow($stdin).to receive(:gets).and_return("Hello\n", "/quit\n")

      expect(formatter).to receive(:warning).with(/Maximum tool rounds/)
      command.execute
    end

    it "handles AuthenticationError from submit_tool_results" do
      tool_call_response = {
        "type" => "tool_calls",
        "conversation_id" => 1,
        "tool_calls" => [{ "id" => "tc_1", "name" => "read_file", "input" => { "path" => "test.rb" } }]
      }

      File.write(File.join(tmpdir, "test.rb"), "code")
      allow(Rubyn.api_client).to receive(:agent_message).and_return(tool_call_response)
      allow(Rubyn.api_client).to receive(:submit_tool_results).and_raise(Rubyn::AuthenticationError, "Expired")

      allow($stdin).to receive(:gets).and_return("Hello\n", "/quit\n")
      expect(formatter).to receive(:error).with("Authentication failed: Expired")
      command.execute
    end

    it "handles APIError from submit_tool_results" do
      tool_call_response = {
        "type" => "tool_calls",
        "conversation_id" => 1,
        "tool_calls" => [{ "id" => "tc_1", "name" => "read_file", "input" => { "path" => "test.rb" } }]
      }

      File.write(File.join(tmpdir, "test.rb"), "code")
      allow(Rubyn.api_client).to receive(:agent_message).and_return(tool_call_response)
      allow(Rubyn.api_client).to receive(:submit_tool_results).and_raise(Rubyn::APIError, "Server error")

      allow($stdin).to receive(:gets).and_return("Hello\n", "/quit\n")
      expect(formatter).to receive(:error).with("Server error")
      command.execute
    end

    it "extracts @file references from input" do
      test_file = File.join(tmpdir, "my_file.rb")
      File.write(test_file, "class MyFile; end")

      allow($stdin).to receive(:gets).and_return("Check @#{test_file}\n", "/quit\n")
      command.execute
      expect(WebMock).to have_requested(:post, "https://api.rubyn.dev/api/v1/ai/agent")
    end
  end

  describe "#format_tool_params" do
    let(:command_instance) { described_class.new }

    before do
      # Set up configuration so we can instantiate
    end

    it "formats short params" do
      result = command_instance.send(:format_tool_params, { "path" => "file.rb" })
      expect(result).to eq("path: file.rb")
    end

    it "truncates long param values" do
      long_value = "a" * 100
      result = command_instance.send(:format_tool_params, { "content" => long_value })
      expect(result).to include("...")
      expect(result.length).to be < 100
    end

    it "returns empty string for non-hash" do
      result = command_instance.send(:format_tool_params, nil)
      expect(result).to eq("")
    end

    it "joins multiple params with commas" do
      result = command_instance.send(:format_tool_params, { "path" => "a.rb", "content" => "code" })
      expect(result).to eq("path: a.rb, content: code")
    end
  end

  describe "#extract_file_context" do
    it "returns existing files from @references" do
      test_file = File.join(tmpdir, "real.rb")
      File.write(test_file, "code")
      result = command.send(:extract_file_context, "Check @#{test_file}")
      expect(result).to include(test_file)
    end

    it "ignores non-existing @references" do
      result = command.send(:extract_file_context, "Check @nonexistent.rb")
      expect(result).to be_empty
    end
  end
end
