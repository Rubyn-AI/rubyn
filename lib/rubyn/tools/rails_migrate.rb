# frozen_string_literal: true

require "open3"
require_relative "base_tool"
require_relative "registry"

module Rubyn
  module Tools
    class RailsMigrate < BaseTool
      DESCRIPTION = "Run pending database migrations"
      PARAMETERS = {
        direction: { type: :string, description: "Migration direction: up or down (default up)", required: false },
        version: { type: :string, description: "Specific migration version", required: false }
      }.freeze
      REQUIRES_CONFIRMATION = true

      def execute(params)
        direction = (params[:direction] || "up").strip.downcase
        version = params[:version]

        command = build_command(direction, version)
        return command if command.is_a?(Hash) && command[:error]

        begin
          stdout, stderr, status = Open3.capture3(command, chdir: project_root)
        rescue StandardError => e
          return error("Failed to run migration: #{e.message}")
        end

        return error("Migration failed: #{stderr}") unless status.exitstatus.zero?

        success(output: stdout)
      end

      private

      def build_command(direction, version)
        case direction
        when "up"
          "bundle exec rails db:migrate"
        when "down"
          if version && !version.strip.empty?
            "bundle exec rails db:migrate:down VERSION=#{version}"
          else
            "bundle exec rails db:rollback"
          end
        else
          error("Invalid direction: #{direction}. Must be 'up' or 'down'")
        end
      end
    end

    Registry.register("rails_migrate", RailsMigrate)
  end
end
