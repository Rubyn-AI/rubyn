# frozen_string_literal: true

module Rubyn
  module Commands
    class Spec < Base
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

        formatter.info("Generating specs for #{File.basename(file)}...")
        formatter.newline
        begin
          result = Rubyn.api_client.generate_spec(
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
          prompt_write_spec(relative_path, full_response, formatter)
        rescue Rubyn::AuthenticationError => e
          formatter.error("Authentication failed: #{e.message}")
        rescue Rubyn::APIError => e
          formatter.error(e.message)
        end
      end

      private

      def prompt_write_spec(source_path, response, formatter)
        code_match = response.match(/```ruby\n(.*?)```/m)
        return unless code_match

        spec_content = code_match[1]
        spec_path = derive_spec_path(source_path)

        print "\nWrite spec to #{spec_path}? (y/n) "
        choice = $stdin.gets&.strip&.downcase

        if choice == "y"
          FileUtils.mkdir_p(File.dirname(spec_path))
          File.write(spec_path, spec_content)
          formatter.success("Spec written to #{spec_path}")
        else
          formatter.info("Spec discarded.")
        end
      end

      def derive_spec_path(source_path)
        source_path
          .sub(%r{^app/}, "spec/")
          .sub(%r{^lib/}, "spec/")
          .sub(/\.rb$/, "_spec.rb")
      end
    end
  end
end
