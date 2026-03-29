# frozen_string_literal: true

require_relative "base_tool"
require_relative "registry"

module Rubyn
  module Tools
    class ReadFile < BaseTool
      DESCRIPTION = "Read the contents of a file"
      PARAMETERS = {
        path: { type: :string, description: "Path to the file to read", required: true },
        line_start: { type: :integer, description: "Starting line number (1-based)", required: false },
        line_end: { type: :integer, description: "Ending line number (1-based, inclusive)", required: false }
      }.freeze
      REQUIRES_CONFIRMATION = false

      def execute(params)
        resolved = resolve_path(params[:path])
        return resolved if resolved.is_a?(Hash) && resolved[:error]

        return error("File not found: #{params[:path]}") unless File.exist?(resolved)
        return error("Not a file: #{params[:path]}") unless File.file?(resolved)

        rel = relative_path(resolved)
        if sensitive_file?(rel) && !params[:skip_sensitive_check]
          return error("sensitive_file:#{params[:path]}")
        end

        lines = File.readlines(resolved)
        total_lines = lines.length

        line_start = params[:line_start]&.to_i
        line_end = params[:line_end]&.to_i

        return success(path: params[:path], content: lines.join, line_count: total_lines) unless line_start || line_end

        line_start = [line_start || 1, 1].max
        line_end = [line_end || total_lines, total_lines].min

        return error("line_start (#{line_start}) cannot be greater than line_end (#{line_end})") if line_start > line_end

        content = lines[(line_start - 1)..(line_end - 1)].join
        success(path: params[:path], content: content, line_count: total_lines)
      end
    end

    Registry.register("read_file", ReadFile)
  end
end
