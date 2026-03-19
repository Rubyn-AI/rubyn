# frozen_string_literal: true

module Rubyn
  module Commands
    class Review < Base
      def execute(file_or_dir)
        formatter = Rubyn::Output::Formatter
        ensure_configured!
        auto_index_if_needed!

        files = resolve_files(file_or_dir)
        if files.empty?
          formatter.error("No Ruby files found in: #{file_or_dir}")
          return
        end

        formatter.info("Reviewing #{files.size} file(s)...")
        formatter.newline

        formatted_files = files.map do |file|
          { file_path: relative_to_project(file), code: File.read(file) }
        end

        file_paths = files.map { |f| relative_to_project(f) }
        formatted_context = file_paths.flat_map { |rel_path| build_context_files(rel_path) }
                                      .uniq { |ctx| ctx[:file_path] }
                                      .reject { |ctx| file_paths.include?(ctx[:file_path]) }

        formatter.header(formatted_files.map { |f| f[:file_path] }.join(", "))

        begin
          result = Rubyn.api_client.review(
            files: formatted_files,
            context_files: formatted_context,
            project_token: project_token
          )

          formatter.print_content(result["response"] || "")
          formatter.newline
          formatter.credit_usage(result["credits_used"], nil) if result["credits_used"]
        rescue Rubyn::AuthenticationError => e
          formatter.error("Authentication failed: #{e.message}")
        rescue Rubyn::APIError => e
          formatter.error(e.message)
        end
      end

      private

      def resolve_files(path)
        if File.directory?(path)
          Dir.glob(File.join(path, "**/*.rb"))
        elsif File.exist?(path)
          [path]
        else
          []
        end
      end
    end
  end
end
