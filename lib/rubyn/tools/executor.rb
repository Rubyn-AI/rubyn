# frozen_string_literal: true

module Rubyn
  module Tools
    class Executor
      attr_reader :project_root, :auto_confirm

      def initialize(project_root = Dir.pwd, auto_confirm: false)
        @project_root = project_root
        @auto_confirm = auto_confirm
      end

      # server_requires_confirmation: the API's flag for whether this call needs user approval.
      # Falls back to the tool's local REQUIRES_CONFIRMATION constant if not provided.
      def execute(tool_name, params, server_requires_confirmation: nil)
        klass = Registry.get(tool_name)
        return { success: false, error: "Unknown tool: #{tool_name}" } unless klass

        tool = klass.new(project_root)

        needs_confirmation = if server_requires_confirmation.nil?
                               tool.requires_confirmation?
                             else
                               server_requires_confirmation
                             end

        if needs_confirmation && !auto_confirm && !confirm_action(tool_name, params)
          return { success: false, error: "denied_by_user" }
        end

        result = tool.call(params)

        if result.is_a?(Hash) && result[:error].to_s.start_with?("sensitive_file:")
          file = result[:error].sub("sensitive_file:", "")
          Rubyn::Output::Formatter.warning("Agent wants to read sensitive file: #{file}")
          print "Allow? (y/n) "
          if $stdin.gets&.strip&.downcase == "y"
            tool.call(params.merge(skip_sensitive_check: true))
          else
            { success: false, error: "denied_by_user" }
          end
        else
          result
        end
      rescue StandardError => e
        { success: false, error: "#{e.class}: #{e.message}" }
      end

      private

      def confirm_action(tool_name, params)
        summary = format_action(tool_name, params)
        Rubyn::Output::Formatter.warning("Agent wants to: #{summary}")
        print "Allow? (y/n) "
        response = $stdin.gets&.strip&.downcase
        response == "y"
      end

      ACTION_FORMATTERS = {
        "write_file"        => ->(p) { "write to #{p[:path]}" },
        "create_file"       => ->(p) { "write to #{p[:path]}" },
        "patch_file"        => ->(p) { "edit #{p[:path]}" },
        "delete_file"       => ->(p) { "delete #{p[:path]}" },
        "move_file"         => ->(p) { "move #{p[:source]} to #{p[:destination]}" },
        "run_command"       => ->(p) { "run: #{p[:command]}" },
        "run_tests"         => ->(p) { "run tests: #{p[:path] || "full suite"}" },
        "rails_generate"    => ->(p) { "rails generate #{p[:generator]} #{p[:args]}" },
        "rails_migrate"     => ->(_) { "rails db:migrate" },
        "bundle_add"        => ->(p) { "add gem '#{p[:gem_name]}' to Gemfile" },
        "git_commit"        => ->(p) { "git commit: #{p[:message]}" },
        "git_create_branch" => ->(p) { "create branch: #{p[:branch_name]}" }
      }.freeze

      def format_action(tool_name, params)
        p = BaseTool.symbolize_params(params)
        formatter = ACTION_FORMATTERS[tool_name]
        formatter ? formatter.call(p) : "#{tool_name} #{params.inspect}"
      end
    end
  end
end
