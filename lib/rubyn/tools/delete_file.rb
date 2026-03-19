# frozen_string_literal: true

require_relative "base_tool"
require_relative "registry"

module Rubyn
  module Tools
    class DeleteFile < BaseTool
      DESCRIPTION = "Delete a file"
      PARAMETERS = {
        path: { type: :string, description: "Path to the file to delete", required: true }
      }.freeze
      REQUIRES_CONFIRMATION = true

      def execute(params)
        resolved = resolve_path(params[:path])
        return resolved if resolved.is_a?(Hash) && resolved[:error]

        return error("File not found: #{params[:path]}") unless File.exist?(resolved)

        File.delete(resolved)

        success(path: params[:path])
      end
    end

    Registry.register("delete_file", DeleteFile)
  end
end
