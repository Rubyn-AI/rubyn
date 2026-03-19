# frozen_string_literal: true

module Rubyn
  module Tools
    class FindReferences < BaseTool
      DESCRIPTION = "Find all references to a class, method, or constant across the project"
      PARAMETERS = {
        identifier: { type: "string", required: true, description: "The class, method, or constant name to find" },
        type: { type: "string", required: false,
                description: "Type of identifier: 'class', 'method', 'constant', or 'any' (default 'any')" }
      }.freeze
      REQUIRES_CONFIRMATION = false

      MAX_RESULTS = 100

      def execute(params)
        identifier = params[:identifier]
        return error("Missing required parameter: identifier") unless identifier

        ref_type = params[:type] || "any"

        regex = build_regex(identifier, ref_type)
        return error("Invalid reference type: #{ref_type}") unless regex

        references = []
        rb_files = Dir.glob(File.join(project_root, "**", "*.rb"))

        rb_files.each do |file|
          break if references.size >= MAX_RESULTS
          next if excluded?(file)

          search_file_for_references(file, regex, references)
        end

        success(identifier: identifier, references: references)
      end

      private

      def build_regex(identifier, type)
        escaped = Regexp.escape(identifier)
        case type
        when "method"
          Regexp.new("(?:\\.#{escaped}\\b|\\bdef\\s+#{escaped}\\b)")
        when "class", "constant", "any"
          Regexp.new("\\b#{escaped}\\b")
        end
      end

      def search_file_for_references(file, regex, references)
        File.open(file, "r:UTF-8") do |f|
          f.each_line.with_index(1) do |line, line_number|
            break if references.size >= MAX_RESULTS

            if line.match?(regex)
              references << {
                file: relative_path(file),
                line_number: line_number,
                line: line.chomp.slice(0, 500)
              }
            end
          end
        end
      rescue ArgumentError, Encoding::InvalidByteSequenceError, Encoding::UndefinedConversionError
        # Skip files with encoding issues
      end

    end
  end
end

Rubyn::Tools::Registry.register("find_references", Rubyn::Tools::FindReferences)
