# frozen_string_literal: true

require "open3"
require "shellwords"
require_relative "base_tool"
require_relative "registry"

module Rubyn
  module Tools
    class GitCommit < BaseTool
      DESCRIPTION = "Stage files and create a git commit"
      PARAMETERS = {
        message: { type: :string, description: "Commit message", required: true },
        files: { type: :array, description: "Specific files to stage (defaults to all changed)", required: false }
      }.freeze
      REQUIRES_CONFIRMATION = true

      def execute(params)
        message = params[:message]
        return error("message is required") unless message && !message.strip.empty?

        files = params[:files]

        # Stage files
        add_command = if files.is_a?(Array) && !files.empty?
                        escaped_files = files.map { |f| Shellwords.escape(f) }.join(" ")
                        "git add #{escaped_files}"
                      else
                        "git add -A"
                      end

        begin
          _stdout, stderr, status = Open3.capture3(add_command, chdir: project_root)
        rescue StandardError => e
          return error("Failed to stage files: #{e.message}")
        end

        return error("git add failed: #{stderr}") unless status.exitstatus.zero?

        # Create commit
        begin
          stdout, stderr, status = Open3.capture3("git", "commit", "-m", message, chdir: project_root)
        rescue StandardError => e
          return error("Failed to create commit: #{e.message}")
        end

        return error("git commit failed: #{stderr}") unless status.exitstatus.zero?

        # Extract commit hash
        commit_hash = extract_commit_hash(stdout)

        success(hash: commit_hash, message: message)
      end

      private

      def extract_commit_hash(output)
        match = output.match(%r{\[[\w\-/]+\s+([a-f0-9]+)\]})
        match ? match[1] : "unknown"
      end
    end

    Registry.register("git_commit", GitCommit)
  end
end
