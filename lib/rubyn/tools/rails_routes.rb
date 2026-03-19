# frozen_string_literal: true

require "open3"
require "shellwords"
require_relative "base_tool"
require_relative "registry"

module Rubyn
  module Tools
    class RailsRoutes < BaseTool
      DESCRIPTION = "Show Rails routes, optionally filtered by a pattern"
      PARAMETERS = {
        pattern: { type: :string, description: "Grep filter for routes", required: false }
      }.freeze
      REQUIRES_CONFIRMATION = false

      def execute(params)
        command = "bundle exec rails routes"
        command = "#{command} -g #{Shellwords.shellescape(params[:pattern])}" if params[:pattern] && !params[:pattern].strip.empty?

        begin
          stdout, stderr, status = Open3.capture3(command, chdir: project_root)
        rescue StandardError => e
          return error("Failed to run rails routes: #{e.message}")
        end

        return error("rails routes failed: #{stderr}") unless status.exitstatus.zero?

        success(routes: stdout)
      end
    end

    Registry.register("rails_routes", RailsRoutes)
  end
end
