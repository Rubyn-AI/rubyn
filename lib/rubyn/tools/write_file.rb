# frozen_string_literal: true

require "fileutils"
require_relative "base_tool"
require_relative "registry"

module Rubyn
  module Tools
    class WriteFile < BaseTool
      DESCRIPTION = "Write content to a file, creating or overwriting it"
      PARAMETERS = {
        path: { type: :string, description: "Path to the file to write", required: true },
        content: { type: :string, description: "Content to write to the file", required: true }
      }.freeze
      REQUIRES_CONFIRMATION = true

      def execute(params)
        resolved = resolve_path(params[:path])
        return resolved if resolved.is_a?(Hash) && resolved[:error]

        FileUtils.mkdir_p(File.dirname(resolved))
        bytes_written = File.write(resolved, params[:content])

        success(path: params[:path], bytes_written: bytes_written)
      end
    end

    Registry.register("write_file", WriteFile)
  end
end
