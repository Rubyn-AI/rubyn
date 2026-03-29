# frozen_string_literal: true

module Rubyn
  module Tools
    class SearchFiles < BaseTool
      DESCRIPTION = "Search file contents for a pattern (grep)"
      PARAMETERS = {
        pattern: { type: "string", required: true, description: "Search pattern (regular expression)" },
        path: { type: "string", required: false, description: "Directory to search in (defaults to project root)" },
        file_pattern: { type: "string", required: false, description: "File glob pattern to filter (e.g. '*.rb')" }
      }.freeze
      REQUIRES_CONFIRMATION = false

      MAX_MATCHES = 100
      MAX_LINE_LENGTH = 500
      MAX_FILE_SIZE = 2_000_000

      def execute(params)
        return error("Missing required parameter: pattern") unless params[:pattern]

        begin
          regex = Regexp.new(params[:pattern])
        rescue RegexpError => e
          return error("Invalid regex pattern: #{e.message}")
        end

        search_path = params[:path] || "."
        file_pattern = params[:file_pattern]

        resolved = resolve_path(search_path)
        return resolved if resolved.is_a?(Hash) && resolved[:error]

        return error("Path not found: #{search_path}") unless File.exist?(resolved)

        matches = []
        glob = file_pattern ? File.join(resolved, "**", file_pattern) : File.join(resolved, "**", "*")

        Dir.glob(glob).each do |file|
          break if matches.size >= MAX_MATCHES
          next unless File.file?(file)
          next if excluded?(file)
          next if blocked_file?(relative_path(file))
          next if sensitive_file?(relative_path(file))
          next if binary?(file)

          search_in_file(file, regex, matches)
        end

        success(pattern: params[:pattern], matches: matches)
      end

      private

      def search_in_file(file, regex, matches)
        File.open(file, "r:UTF-8") do |f|
          f.each_line.with_index(1) do |line, line_number|
            break if matches.size >= MAX_MATCHES

            if line.match?(regex)
              matches << {
                file: relative_path(file),
                line_number: line_number,
                line: line.chomp.slice(0, MAX_LINE_LENGTH)
              }
            end
          end
        end
      rescue ArgumentError, Encoding::InvalidByteSequenceError, Encoding::UndefinedConversionError
        # Skip files with encoding issues
      end

      def binary?(file)
        return true if File.size(file) > MAX_FILE_SIZE

        sample = File.read(file, 8192) || ""
        sample.include?("\x00")
      rescue Errno::EACCES, Errno::ENOENT, IOError
        true
      end
    end
  end
end

Rubyn::Tools::Registry.register("search_files", Rubyn::Tools::SearchFiles)
