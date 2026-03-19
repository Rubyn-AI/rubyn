# frozen_string_literal: true

# Boot the dummy Rails app BEFORE requiring rubyn, so the engine loads correctly
ENV["RAILS_ENV"] = "test"
require_relative "dummy/config/environment"

# Now require rubyn engine explicitly (in case it was loaded before Rails::Engine existed)
require "rubyn/engine/engine" unless defined?(Rubyn::Engine)

require "rspec/rails"
require "webmock/rspec"

WebMock.disable_net_connect!

Dir[File.join(__dir__, "support", "**/*.rb")].each { |f| require f }

RSpec.configure do |config|
  config.include WebmockStubs
  config.include FixtureHelpers

  config.use_transactional_fixtures = false
  config.infer_spec_type_from_file_location!

  # Disable CSRF verification in test so JSON POSTs work without tokens
  # Stub version checker so it doesn't hit RubyGems in tests
  config.before(:each, type: :request) do
    ActionController::Base.allow_forgery_protection = false
    allow(Rubyn::VersionChecker).to receive(:update_message).and_return(nil)
  end

  config.after(:each, type: :request) do
    ActionController::Base.allow_forgery_protection = true
  end



  config.before do
    Rubyn.reset!
    Rubyn.configuration.api_url = "https://api.rubyn.dev"
  end
end
