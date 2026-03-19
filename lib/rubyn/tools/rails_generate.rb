# frozen_string_literal: true

require "open3"
require_relative "base_tool"
require_relative "registry"

module Rubyn
  module Tools
    class RailsGenerate < BaseTool
      DESCRIPTION = "Run a Rails generator"
      PARAMETERS = {
        generator: { type: :string, description: "Generator name (e.g. migration, model)", required: true },
        args: { type: :string, description: "Generator arguments (e.g. AddDeletedAtToOrders deleted_at:datetime)",
                required: true }
      }.freeze
      REQUIRES_CONFIRMATION = true

      def execute(params)
        generator = params[:generator]
        args = params[:args]
        return error("generator is required") unless generator && !generator.strip.empty?
        return error("args is required") unless args && !args.strip.empty?

        command = "bundle exec rails generate #{generator} #{args}"

        begin
          stdout, stderr, status = Open3.capture3(command, chdir: project_root)
        rescue StandardError => e
          return error("Failed to run rails generate: #{e.message}")
        end

        return error("rails generate failed: #{stderr}") unless status.exitstatus.zero?

        success(output: stdout)
      end
    end

    Registry.register("rails_generate", RailsGenerate)
  end
end
