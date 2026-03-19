# frozen_string_literal: true

require "open3"
require "timeout"
require_relative "base_tool"
require_relative "registry"

module Rubyn
  module Tools
    class RunCommand < BaseTool
      DESCRIPTION = "Execute a shell command in the project directory"
      PARAMETERS = {
        command: { type: :string, description: "Shell command to execute", required: true },
        timeout: { type: :integer, description: "Timeout in seconds (default 30)", required: false }
      }.freeze
      REQUIRES_CONFIRMATION = true

      DEFAULT_TIMEOUT = 30

      def execute(params)
        command = params[:command]
        return error("command is required") unless command && !command.strip.empty?

        timeout_seconds = (params[:timeout] || DEFAULT_TIMEOUT).to_i

        stdout, stderr, status = nil
        begin
          Timeout.timeout(timeout_seconds) do
            stdout, stderr, status = Open3.capture3(command, chdir: project_root)
          end
        rescue Timeout::Error
          return error("Command timed out after #{timeout_seconds} seconds")
        rescue StandardError => e
          return error("Failed to execute command: #{e.message}")
        end

        stdout = truncate_output(stdout)
        stderr = truncate_output(stderr)

        success(command: command, stdout: stdout, stderr: stderr, exit_code: status.exitstatus)
      end

      private
    end

    Registry.register("run_command", RunCommand)
  end
end
