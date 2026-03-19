# frozen_string_literal: true

require "simplecov"
SimpleCov.start do
  add_filter "/spec/"
  add_filter "/lib/rubyn/engine/"

  add_group "Client", "lib/rubyn/client"
  add_group "Commands", "lib/rubyn/commands"
  add_group "Config", "lib/rubyn/config"
  add_group "Context", "lib/rubyn/context"
  add_group "Output", "lib/rubyn/output"
  add_group "Tools", "lib/rubyn/tools"

  minimum_coverage 95
end

require "rubyn"
require "webmock/rspec"
require "json"
require "tmpdir"
require "fileutils"

Dir[File.join(__dir__, "support", "**/*.rb")].each { |f| require f }

RSpec.configure do |config|
  config.example_status_persistence_file_path = ".rspec_status"
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.include WebmockStubs
  config.include FixtureHelpers

  config.before do
    Rubyn.reset!
    Rubyn.configuration.api_url = "https://api.rubyn.dev"
  end

  config.exclude_pattern = "{spec/fixtures/**/*,spec/dummy/**/*_spec.rb}"
end
