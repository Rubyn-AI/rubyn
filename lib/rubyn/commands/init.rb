# frozen_string_literal: true

require "securerandom"
require "tty-prompt"

module Rubyn
  module Commands
    class Init
      PROJECT_TOKEN_PREFIX = "rprj_".freeze
      PROJECT_TOKEN_HEX_LENGTH = 12
      TOKEN_PREVIEW_LENGTH = 9

      def execute
        formatter = Rubyn::Output::Formatter
        prompt = TTY::Prompt.new

        formatter.header("Rubyn Init")

        if Rubyn::Config::ProjectConfig.exists?
          join_existing_project(formatter)
          return
        end

        api_key = resolve_api_key(formatter, prompt)
        return unless api_key

        verify_api_key(formatter, api_key)

        metadata = scan_project(formatter)
        project_token = "#{PROJECT_TOKEN_PREFIX}#{SecureRandom.hex(PROJECT_TOKEN_HEX_LENGTH)}"
        result = sync_project(formatter, metadata, project_token)

        write_project_config(result)
        # offer_indexing(formatter, prompt, result)
        display_summary(formatter, metadata, result)
      end

      private

      def join_existing_project(formatter)
        project_token = Rubyn::Config::ProjectConfig.project_token
        formatter.info("Existing project detected. Joining with token: #{project_token[0..TOKEN_PREVIEW_LENGTH - 1]}...")

        spinner = Rubyn::Output::Spinner.new
        spinner.start("Joining project...")

        begin
          result = Rubyn.api_client.join_project(project_token: project_token)
          spinner.stop_success("Joined!")
          formatter.success("Successfully joined project. Project ID: #{result.dig("project", "id")}")
        rescue Rubyn::Error => e
          spinner.stop_error("Failed")
          formatter.error("Could not join project: #{e.message}")
        end
      end

      def resolve_api_key(formatter, prompt)
        if Rubyn::Config::Credentials.exists?
          formatter.info("API key found in credentials")
          return Rubyn::Config::Credentials.api_key
        end

        if ENV["RUBYN_API_KEY"]
          formatter.info("Using RUBYN_API_KEY from environment")
          return ENV["RUBYN_API_KEY"]
        end

        api_key = prompt.ask("Enter your Rubyn API key:") do |q|
          q.required true
          q.validate(/\Ark_/, "API key should start with 'rk_'")
        end

        Rubyn::Config::Credentials.store(api_key: api_key)
        formatter.success("API key saved to ~/.rubyn/credentials")
        api_key
      end

      def verify_api_key(formatter, api_key)
        spinner = Rubyn::Output::Spinner.new
        spinner.start("Verifying API key...")

        Rubyn.configuration.api_key = api_key
        result = Rubyn.api_client.verify_auth
        spinner.stop_success("Verified!")

        formatter.info("Authenticated as: #{result.dig("user", "email")}")
        formatter.info("Plan: #{result.dig("user", "plan")}")

        if result.dig("user", "organization_name")
          formatter.info("Team: #{result.dig("user", "organization_name")}")
        end
      rescue Rubyn::AuthenticationError
        spinner.stop_error("Invalid!")
        formatter.error("API key is invalid. Get your key at https://rubyn.dev/settings")
        raise
      end

      def scan_project(_formatter)
        spinner = Rubyn::Output::Spinner.new
        spinner.start("Scanning project...")
        scanner = Rubyn::Context::ProjectScanner.new
        metadata = scanner.scan
        spinner.stop_success("Scanned!")
        metadata
      end

      def sync_project(_formatter, metadata, project_token)
        spinner = Rubyn::Output::Spinner.new
        spinner.start("Syncing project with Rubyn...")
        result = Rubyn.api_client.sync_project(metadata: metadata, project_token: project_token)
        spinner.stop_success("Synced!")
        result
      end

      def write_project_config(result)
        project = result.fetch("project")
        Rubyn::Config::ProjectConfig.write({
                                             "project_token" => project.fetch("project_token"),
                                             "project_id" => project.fetch("id")
                                           })
        write_default_security_config
        ensure_gitignore
      end

      def write_default_security_config
        path = File.join(Dir.pwd, ".rubyn", "security.yml")
        return if File.exist?(path)

        content = <<~YAML
          # Rubyn Security Configuration
          #
          # blocked_files: Files the agent can NEVER read or write.
          #   These are hard-blocked — no confirmation prompt, just denied.
          #
          # sensitive_files: Files the agent can read ONLY with your approval.
          #   You'll be prompted before the agent can access these.
          #
          # Patterns support exact paths and directory prefixes:
          #   - config/master.key        (exact file)
          #   - config/credentials       (entire directory)
          #   - .env.*                   (glob pattern)

          blocked_files:
            - config/master.key
            - config/credentials.yml.enc
            - config/credentials

          sensitive_files:
            - .env
            - .env.*
            - config/database.yml
            - config/secrets.yml
        YAML

        File.write(path, content)
      end

      def ensure_gitignore
        gitignore_path = File.join(Dir.pwd, ".gitignore")
        return unless File.exist?(gitignore_path)

        content = File.read(gitignore_path)
        return if content.match?(/^\/?\.rubyn\/?$/)

        File.open(gitignore_path, "a") do |f|
          f.puts unless content.end_with?("\n")
          f.puts "\n# Rubyn project config"
          f.puts ".rubyn/"
        end
      end

      # def offer_indexing(formatter, prompt, _result)
      #   return unless prompt.yes?("Analyse your codebase for enhanced context? (Pro feature)")
      #
      #   spinner = Rubyn::Output::Spinner.new
      #   spinner.start("Analysing codebase...")
      #   indexer = Rubyn::Context::CodebaseIndexer.new
      #   stats = indexer.index
      #   spinner.stop_success("Done!")
      #   formatter.info("Analysed #{stats[:indexed]} files (#{stats[:skipped]} unchanged)")
      # rescue Rubyn::AuthenticationError
      #   spinner&.stop_error("Skipped")
      #   formatter.warning("Codebase analysis requires a Pro plan. Skipping.")
      # rescue Rubyn::APIError => e
      #   spinner&.stop_error("Failed")
      #   formatter.error("Could not analyse codebase: #{e.message}")
      # end

      def display_summary(formatter, metadata, result)
        formatter.newline
        formatter.header("Project Summary")
        formatter.info("Project: #{metadata[:project_name]}")
        formatter.info("Type: #{metadata[:project_type]}")
        formatter.info("Ruby: #{metadata[:ruby_version] || "not detected"}")
        formatter.info("Rails: #{metadata[:rails_version] || "N/A"}")
        formatter.info("Tests: #{metadata[:test_framework]}")
        formatter.info("Credits: N/A")
        formatter.newline
        formatter.info("Run `rubyn refactor <file>` to get started.")
        formatter.info("Or visit http://localhost:3000/rubyn for the dashboard.")
      end
    end
  end
end
