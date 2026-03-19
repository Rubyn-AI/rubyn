# frozen_string_literal: true

require "open3"
require_relative "base_tool"
require_relative "registry"

module Rubyn
  module Tools
    class GitCreateBranch < BaseTool
      DESCRIPTION = "Create and checkout a new git branch"
      PARAMETERS = {
        branch_name: { type: :string, description: "Name of the new branch", required: true },
        from: { type: :string, description: "Base branch (defaults to current branch)", required: false }
      }.freeze
      REQUIRES_CONFIRMATION = true

      VALID_BRANCH_PATTERN = %r{\A[a-zA-Z0-9\-_/]+\z}

      def execute(params)
        branch_name = params[:branch_name]
        return error("branch_name is required") unless branch_name && !branch_name.strip.empty?

        unless branch_name.match?(VALID_BRANCH_PATTERN)
          return error(
            "Invalid branch name: '#{branch_name}'. Use letters, numbers, hyphens, underscores, or slashes."
          )
        end

        from = params[:from]
        if from && !from.strip.empty?
          unless from.match?(VALID_BRANCH_PATTERN)
            return error(
              "Invalid base branch name: '#{from}'. Use letters, numbers, hyphens, underscores, or slashes."
            )
          end
        end

        cmd = if from && !from.strip.empty?
                ["git", "checkout", "-b", branch_name, from]
              else
                ["git", "checkout", "-b", branch_name]
              end

        begin
          _, stderr, status = Open3.capture3(*cmd, chdir: project_root)
        rescue StandardError => e
          return error("Failed to create branch: #{e.message}")
        end

        return error("git checkout failed: #{stderr}") unless status.exitstatus.zero?

        success(branch: branch_name)
      end
    end

    Registry.register("git_create_branch", GitCreateBranch)
  end
end
