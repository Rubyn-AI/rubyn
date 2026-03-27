# frozen_string_literal: true

module Rubyn
  module Commands
    class Refactor < Base
      def execute(file)
        formatter = Rubyn::Output::Formatter
        ensure_configured!
        auto_index_if_needed!

        unless File.exist?(file)
          formatter.error("File not found: #{file}")
          return
        end

        file_content = File.read(file)
        relative_path = relative_to_project(file)
        formatted_context = build_context_files(relative_path)

        formatter.info("Analyzing #{File.basename(file)}...")
        formatter.info("Context: #{formatted_context.size} related file(s)")
        formatter.newline
        begin
          result = Rubyn.api_client.refactor(
            file_path: relative_path,
            code: file_content,
            context_files: formatted_context,
            project_token: project_token
          )

          full_response = result["response"] || ""
          formatter.print_content(full_response)
          formatter.newline
          formatter.credit_usage(result["credits_used"], nil) if result["credits_used"]
          formatter.newline

          file_blocks = Context::ResponseParser.extract_file_blocks(full_response)
          if file_blocks.any?
            applier = Context::FileApplier.new(original_file: file, formatter: formatter)
            applier.apply(file_blocks)
          end
        rescue Rubyn::AuthenticationError => e
          formatter.error("Authentication failed: #{e.message}")
        rescue Rubyn::APIError => e
          formatter.error(e.message)
        end
      end
    end
  end
end
