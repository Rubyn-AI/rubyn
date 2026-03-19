# frozen_string_literal: true

require "set"

module Rubyn
  module Commands
    class Agent < Base
      MAX_TOOL_ROUNDS = 25
      MAX_PARAM_DISPLAY_LENGTH = 50

      def execute
        formatter = Rubyn::Output::Formatter
        ensure_configured!
        auto_index_if_needed!

        formatter.header("Rubyn Agent")
        formatter.info("Type your message. Use @filename to attach files.")
        formatter.info("Commands: /quit /credits /new")
        formatter.newline

        @conversation_id = nil
        @project_token = project_token
        @executor = Rubyn::Tools::Executor.new(Dir.pwd)

        loop do
          print "you> "
          input = $stdin.gets
          break if input.nil?

          input = input.strip
          break if ["/quit", "exit"].include?(input)

          next if input.empty?

          dispatch_input(input, formatter)
        end

        formatter.newline
        formatter.info("Session ended.")
      end

      private

      def dispatch_input(input, formatter)
        case input
        when "/credits"
          show_credits(formatter)
        when "/new"
          @conversation_id = nil
          formatter.info("New conversation started.")
        else
          send_message(input, formatter)
        end
      end

      def send_message(input, formatter)
        file_context = extract_file_context(input)
        message = input.gsub(/@\S+/, "").strip

        begin
          result = Rubyn.api_client.agent_message(
            conversation_id: @conversation_id,
            message: message,
            file_context: file_context,
            project_token: @project_token
          )

          @conversation_id ||= result["conversation_id"]

          display_agent_result(result, formatter)
        rescue Rubyn::AuthenticationError => e
          formatter.error("Authentication failed: #{e.message}")
        rescue Rubyn::APIError => e
          formatter.error(e.message)
        end
      end

      def display_agent_result(result, formatter)
        if result.fetch("type", nil) == "tool_calls"
          tool_calls = result.fetch("tool_calls", []).map do |tc|
            {
              id: tc.fetch("id"),
              name: tc.fetch("name"),
              input: tc.fetch("input", {}),
              requires_confirmation: tc.fetch("requires_confirmation", false)
            }
          end

          formatter.credit_usage(result["credits_used"], nil) if result["credits_used"]

          process_tool_loop(tool_calls, formatter)
        else
          print "rubyn> "
          formatter.print_content(result.dig("response") || result.dig("content") || "")
          formatter.newline
          formatter.credit_usage(result["credits_used"], nil) if result["credits_used"]
        end
      end

      def process_tool_loop(tool_calls, formatter, round: 0)
        if round >= MAX_TOOL_ROUNDS
          formatter.warning("Maximum tool rounds (#{MAX_TOOL_ROUNDS}) reached. Stopping.")
          return
        end

        results = execute_tool_calls(tool_calls, formatter)

        begin
          result = Rubyn.api_client.submit_tool_results(
            conversation_id: @conversation_id,
            tool_results: results,
            project_token: @project_token
          )

          @conversation_id ||= result["conversation_id"]

          display_agent_result(result, formatter)
        rescue Rubyn::AuthenticationError => e
          formatter.error("Authentication failed: #{e.message}")
        rescue Rubyn::APIError => e
          formatter.error(e.message)
        end
      end

      def execute_tool_calls(tool_calls, formatter)
        tool_calls.map do |tc|
          formatter.info("Tool: #{tc[:name]}(#{format_tool_params(tc[:input])})")

          result = @executor.execute(
            tc[:name],
            tc[:input],
            server_requires_confirmation: tc[:requires_confirmation]
          )

          if result[:success]
            Rubyn::Output::Formatter.success("#{tc[:name]} completed")
          elsif result[:error] == "denied_by_user"
            Rubyn::Output::Formatter.warning("#{tc[:name]} denied by user")
          else
            Rubyn::Output::Formatter.error("#{tc[:name]}: #{result[:error]}")
          end

          { tool_call_id: tc[:id], result: result.is_a?(Hash) ? result.to_json : result }
        end
      end

      def format_tool_params(params)
        return "" unless params.is_a?(Hash)

        params.map do |k, v|
          val = v.is_a?(String) && v.length > MAX_PARAM_DISPLAY_LENGTH ? "#{v[0..MAX_PARAM_DISPLAY_LENGTH - 3]}..." : v
          "#{k}: #{val}"
        end.join(", ")
      end

      # Override base to use larger context limit for agent
      def build_context_files(relative_path)
        resolver = Rubyn::Context::FileResolver.new
        related = resolver.resolve(relative_path)
        builder = Rubyn::Context::ContextBuilder.new(Dir.pwd, max_bytes: Rubyn::Context::ContextBuilder::AGENT_MAX_CONTEXT_BYTES)
        context = builder.build(relative_path, related)
        context.reject { |path, _| path == relative_path }
               .map { |path, content| { file_path: path, code: content } }
      end

      def extract_file_context(input)
        files = input.scan(/@(\S+)/).flatten.select { |file| File.exist?(file) }
        return [] if files.empty?

        # Resolve dependencies for each attached file so the agent
        # has full context and won't break related code during refactors
        all_files = Set.new(files)
        files.each do |file|
          relative = relative_to_project(file)
          related = build_context_files(relative)
          related.each { |ctx| all_files << ctx[:file_path] }
        end

        all_files.to_a
      end

      def show_credits(formatter)
        result = Rubyn.api_client.get_balance
        formatter.info("Balance: #{result["balance"]} credits")
        formatter.info("Plan: #{result["plan"]}")
      rescue Rubyn::Error => e
        formatter.error(e.message)
      end
    end
  end
end
