# frozen_string_literal: true

require "fileutils"
require_relative "base_tool"
require_relative "registry"

module Rubyn
  module Tools
    class MoveFile < BaseTool
      DESCRIPTION = "Move or rename a file"
      PARAMETERS = {
        source: { type: :string, description: "Path to the source file", required: true },
        destination: { type: :string, description: "Path to the destination", required: true }
      }.freeze
      REQUIRES_CONFIRMATION = true

      def execute(params)
        resolved_source = resolve_path(params[:source])
        return resolved_source if resolved_source.is_a?(Hash) && resolved_source[:error]

        resolved_destination = resolve_path(params[:destination])
        return resolved_destination if resolved_destination.is_a?(Hash) && resolved_destination[:error]

        return error("Source file not found: #{params[:source]}") unless File.exist?(resolved_source)

        FileUtils.mkdir_p(File.dirname(resolved_destination))
        FileUtils.mv(resolved_source, resolved_destination)

        success(source: params[:source], destination: params[:destination])
      end
    end

    Registry.register("move_file", MoveFile)
  end
end
