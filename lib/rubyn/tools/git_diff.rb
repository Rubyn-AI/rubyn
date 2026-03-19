# frozen_string_literal: true

require "open3"
require "shellwords"
require_relative "base_tool"
require_relative "registry"

module Rubyn
  module Tools
    class GitDiff < BaseTool
      DESCRIPTION = "Show current git diff"
      PARAMETERS = {
        path: { type: :string, description: "Specific file to diff", required: false },
        staged: { type: :boolean, description: "Show staged changes (default false)", required: false }
      }.freeze
      REQUIRES_CONFIRMATION = false

      DEFAULT_MAX_OUTPUT_LENGTH = 15_000

      def execute(params)
        command = "git diff"
        command = "#{command} --cached" if params[:staged]
        command = "#{command} -- #{Shellwords.shellescape(params[:path])}" if params[:path] && !params[:path].strip.empty?

        begin
          stdout, stderr, status = Open3.capture3(command, chdir: project_root)
        rescue StandardError => e
          return error("Failed to get git diff: #{e.message}")
        end

        return error("git diff failed: #{stderr}") unless status.exitstatus.zero?

        diff = truncate_output(stdout)
        success(diff: diff)
      end

      private
    end

    Registry.register("git_diff", GitDiff)
  end
end
