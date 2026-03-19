# frozen_string_literal: true

require "fileutils"
require_relative "base_tool"
require_relative "registry"

module Rubyn
  module Tools
    class CreateFile < BaseTool
      DESCRIPTION = "Create a new file. Fails if the file already exists."
      PARAMETERS = {
        path: { type: :string, description: "Path to the file to create", required: true },
        content: { type: :string, description: "Content to write to the new file", required: true }
      }.freeze
      REQUIRES_CONFIRMATION = true

      def execute(params)
        resolved = resolve_path(params[:path])
        return resolved if resolved.is_a?(Hash) && resolved[:error]

        return error("File already exists: #{params[:path]}") if File.exist?(resolved)

        FileUtils.mkdir_p(File.dirname(resolved))
        bytes_written = File.write(resolved, params[:content])

        success(path: params[:path], bytes_written: bytes_written)
      end
    end

    Registry.register("create_file", CreateFile)
  end
end
