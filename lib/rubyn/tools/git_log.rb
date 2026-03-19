# frozen_string_literal: true

require "open3"
require "shellwords"
require_relative "base_tool"
require_relative "registry"

module Rubyn
  module Tools
    class GitLog < BaseTool
      DESCRIPTION = "Show recent git commit history"
      PARAMETERS = {
        count: { type: :integer, description: "Number of commits to show (default 10)", required: false },
        path: { type: :string, description: "Filter by file path", required: false }
      }.freeze
      REQUIRES_CONFIRMATION = false
      DEFAULT_COUNT = 10

      def execute(params)
        count = (params[:count] || DEFAULT_COUNT).to_i
        command = "git log --oneline -#{count}"
        command = "#{command} -- #{Shellwords.shellescape(params[:path])}" if params[:path] && !params[:path].strip.empty?

        begin
          stdout, stderr, status = Open3.capture3(command, chdir: project_root)
        rescue StandardError => e
          return error("Failed to get git log: #{e.message}")
        end

        return error("git log failed: #{stderr}") unless status.exitstatus.zero?

        commits = stdout.strip.split("\n").map do |line|
          hash, *message_parts = line.split
          { hash: hash, message: message_parts.join(" ") }
        end

        success(commits: commits)
      end
    end

    Registry.register("git_log", GitLog)
  end
end
