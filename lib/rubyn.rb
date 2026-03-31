# frozen_string_literal: true

begin
  require "dotenv/load"
rescue LoadError
  # dotenv is optional — only needed for local development with .env files
end

require_relative "rubyn/version"
require_relative "rubyn/version_checker"

module Rubyn
  class Error < StandardError; end
  class AuthenticationError < Error; end
  class ConfigurationError < Error; end
  class APIError < Error; end
  class GitError < Error; end

  class Configuration
    attr_accessor :api_url, :api_key

    def initialize
      @api_url = ENV.fetch("RUBYN_API_URL", "https://app.rubyn.ai")
      @api_key = ENV.fetch("RUBYN_API_KEY", nil)
    end
  end

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    def api_client
      @api_client ||= Client::ApiClient.new
    end

    def reset!
      @configuration = nil
      @api_client = nil
    end
  end
end

require_relative "rubyn/config/credentials"
require_relative "rubyn/config/settings"
require_relative "rubyn/config/project_config"
require_relative "rubyn/client/api_client"
require_relative "rubyn/context/project_scanner"
require_relative "rubyn/context/file_resolver"
require_relative "rubyn/context/context_builder"
require_relative "rubyn/context/codebase_indexer"
require_relative "rubyn/context/response_parser"
require_relative "rubyn/context/file_applier"
require_relative "rubyn/git/branch_diff"
require_relative "rubyn/output/formatter"
require_relative "rubyn/output/diff_renderer"
require_relative "rubyn/output/spinner"
require_relative "rubyn/tools/registry"
require_relative "rubyn/tools/base_tool"
require_relative "rubyn/tools/executor"
require_relative "rubyn/tools/read_file"
require_relative "rubyn/tools/write_file"
require_relative "rubyn/tools/create_file"
require_relative "rubyn/tools/patch_file"
require_relative "rubyn/tools/delete_file"
require_relative "rubyn/tools/move_file"
require_relative "rubyn/tools/list_directory"
require_relative "rubyn/tools/find_files"
require_relative "rubyn/tools/search_files"
require_relative "rubyn/tools/find_references"
require_relative "rubyn/tools/run_command"
require_relative "rubyn/tools/run_tests"
require_relative "rubyn/tools/rails_routes"
require_relative "rubyn/tools/rails_generate"
require_relative "rubyn/tools/rails_migrate"
require_relative "rubyn/tools/bundle_add"
require_relative "rubyn/tools/git_status"
require_relative "rubyn/tools/git_diff"
require_relative "rubyn/tools/git_log"
require_relative "rubyn/tools/git_commit"
require_relative "rubyn/tools/git_create_branch"
require_relative "rubyn/commands/base"
require_relative "rubyn/commands/init"
require_relative "rubyn/commands/refactor"
require_relative "rubyn/commands/spec"
require_relative "rubyn/commands/review"
require_relative "rubyn/commands/agent"
require_relative "rubyn/commands/index"
require_relative "rubyn/commands/usage"
require_relative "rubyn/commands/config"
require_relative "rubyn/commands/dashboard"
require_relative "rubyn/commands/pr"
require_relative "rubyn/cli"

# Load Rails engine when running inside a Rails app
require_relative "rubyn/engine/engine" if defined?(Rails::Engine)
