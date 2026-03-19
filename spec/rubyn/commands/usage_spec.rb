# frozen_string_literal: true

RSpec.describe Rubyn::Commands::Usage do
  let(:tmpdir) { Dir.mktmpdir }
  let(:command) { described_class.new }

  before do
    stub_const("Rubyn::Config::Credentials::CREDENTIALS_DIR", tmpdir)
    stub_const("Rubyn::Config::Credentials::CREDENTIALS_FILE", File.join(tmpdir, "credentials"))

    allow($stdout).to receive(:write)
    allow($stdout).to receive(:print)
  end

  after do
    FileUtils.rm_rf(tmpdir)
  end

  describe "#execute" do
    it "displays balance and history" do
      Rubyn::Config::Credentials.store(api_key: "rk_test")
      stub_get_balance(balance: 75, plan: "pro")
      stub_get_history(entries: [
                         { command: "refactor", credits_charged: 2, model_used: "haiku-4.5", created_at: "2024-01-01" }
                       ])

      command.execute
      expect(WebMock).to have_requested(:get, "https://api.rubyn.dev/api/v1/usage/balance")
      expect(WebMock).to have_requested(:get, %r{usage/history})
    end

    it "raises error when not configured" do
      # Don't store credentials — they should not exist
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("RUBYN_API_KEY").and_return(nil)
      expect { command.execute }.to raise_error(Rubyn::ConfigurationError)
    end

    it "handles API errors gracefully" do
      Rubyn::Config::Credentials.store(api_key: "rk_test")
      allow(Rubyn.api_client).to receive(:get_balance).and_raise(Rubyn::APIError, "Service unavailable")

      formatter = Rubyn::Output::Formatter
      expect(formatter).to receive(:error).with("Service unavailable")
      command.execute
    end
  end
end
