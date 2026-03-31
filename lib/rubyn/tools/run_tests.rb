# frozen_string_literal: true

require "open3"
require_relative "base_tool"
require_relative "registry"

module Rubyn
  module Tools
    class RunTests < BaseTool
      DESCRIPTION = "Run tests for a specific file or the full test suite"
      PARAMETERS = {
        path: { type: :string, description: "Specific test file to run", required: false },
        options: { type: :string, description: "Extra flags like --fail-fast", required: false }
      }.freeze
      REQUIRES_CONFIRMATION = true

      def execute(params)
        command = detect_test_command
        return error("No test framework detected (no spec/ or test/ directory found)") unless command

        # Accept both gem params (path) and API params (files array)
        test_path = params[:path]
        test_path ||= Array(params[:files]).join(" ") if params[:files]
        command = "#{command} #{test_path}" if test_path && !test_path.strip.empty?
        command = "#{command} #{params[:options]}" if params[:options] && !params[:options].strip.empty?

        begin
          stdout, stderr, status = Open3.capture3(command, chdir: project_root)
        rescue StandardError => e
          return error("Failed to run tests: #{e.message}")
        end

        success(
          command: command,
          stdout: stdout,
          stderr: stderr,
          exit_code: status.exitstatus,
          passed: status.exitstatus.zero?
        )
      end

      private

      def detect_test_command
        if Dir.exist?(File.join(project_root, "spec"))
          "bundle exec rspec"
        elsif Dir.exist?(File.join(project_root, "test"))
          "bundle exec rails test"
        end
      end
    end

    Registry.register("run_tests", RunTests)
  end
end
