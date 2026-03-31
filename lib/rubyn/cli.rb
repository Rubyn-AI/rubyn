# frozen_string_literal: true

require "thor"

module Rubyn
  class CLI < Thor
    def self.exit_on_failure?
      true
    end

    no_commands do
      def check_for_updates
        msg = Rubyn::VersionChecker.update_message
        return unless msg

        puts
        puts Pastel.new.yellow(msg)
      rescue Rubyn::Error, Net::HTTPError, SocketError, Timeout::Error
        # Never let update check break the CLI
      end
    end

    def self.start(given_args = ARGV, config = {})
      super
    ensure
      # Check for updates after any command (in a non-blocking way)
      new.check_for_updates if given_args.any? && !%w[help -h --help version -v --version].include?(given_args.first)
    end

    desc "init", "Initialize Rubyn in this project"
    def init
      require_relative "commands/init"
      Commands::Init.new.execute
    end

    desc "refactor FILE", "Refactor a file toward best practices"
    def refactor(file)
      require_relative "commands/refactor"
      Commands::Refactor.new.execute(file)
    end

    desc "spec FILE", "Generate RSpec tests for a file"
    def spec(file)
      require_relative "commands/spec"
      Commands::Spec.new.execute(file)
    end

    desc "review FILE_OR_DIR", "Review code for anti-patterns"
    def review(file_or_dir)
      require_relative "commands/review"
      Commands::Review.new.execute(file_or_dir)
    end

    desc "agent", "Start an interactive conversation with Rubyn"
    def agent
      require_relative "commands/agent"
      Commands::Agent.new.execute
    end

    desc "pr", "Review your changes before opening a pull request"
    option :base, type: :string, default: nil, desc: "Base branch to compare against (default: main or master)"
    def pr
      require_relative "commands/pr"
      Commands::Pr.new.execute(base: options[:base])
    end

    # desc "analyse", "Analyse your codebase for enhanced AI context"
    # option :force, type: :boolean, default: false, desc: "Re-analyse all files, not just changed ones"
    # def analyse
    #   require_relative "commands/index"
    #   Commands::Index.new.execute(force: options[:force])
    # end

    desc "usage", "Show credit balance and recent usage"
    def usage
      require_relative "commands/usage"
      Commands::Usage.new.execute
    end

    desc "config [KEY] [VALUE]", "View or set configuration"
    def config(key = nil, value = nil)
      require_relative "commands/config"
      Commands::Config.new.execute(key, value)
    end

    desc "dashboard", "Open the Rubyn web dashboard"
    def dashboard
      require_relative "commands/dashboard"
      Commands::Dashboard.new.execute
    end
  end
end
