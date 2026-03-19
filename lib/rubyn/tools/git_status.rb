# frozen_string_literal: true

require "open3"
require_relative "base_tool"
require_relative "registry"

module Rubyn
  module Tools
    class GitStatus < BaseTool
      DESCRIPTION = "Show git working tree status"
      PARAMETERS = {}.freeze
      REQUIRES_CONFIRMATION = false

      def execute(_params)
        stdout, stderr, status = Open3.capture3("git status --short", chdir: project_root)
        return error("git status failed: #{stderr}") unless status.exitstatus.zero?

        success(status: stdout, clean: stdout.strip.empty?)
      rescue Errno::ENOENT, Errno::EACCES => e
        error("Failed to get git status: #{e.message}")
      end
    end

    Registry.register("git_status", GitStatus)
  end
end
