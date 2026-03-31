# frozen_string_literal: true

require_relative "base_tool"
require_relative "registry"

module Rubyn
  module Tools
    class PatchFile < BaseTool
      DESCRIPTION = "Apply a targeted find-and-replace edit to a file"
      PARAMETERS = {
        path: { type: :string, description: "Path to the file to patch", required: true },
        find: { type: :string, description: "The string to find in the file", required: true },
        replace: { type: :string, description: "The string to replace with", required: true },
        all_occurrences: { type: :boolean, description: "Replace all occurrences (default: false)", required: false }
      }.freeze
      REQUIRES_CONFIRMATION = true

      def execute(params)
        resolved = resolve_path(params[:path])
        return resolved if resolved.is_a?(Hash) && resolved[:error]

        return error("File not found: #{params[:path]}") unless File.exist?(resolved)

        content = File.read(resolved)
        find = params[:find] || params[:old_text]
        replace = params[:replace] || params[:new_text]

        return error("Missing find/old_text parameter") unless find
        return error("Missing replace/new_text parameter") unless replace
        return error("Find string not found in file: #{params[:path]}") unless content.include?(find)

        all_occurrences = params[:all_occurrences] || false

        if all_occurrences
          replacements = content.scan(find).length
          new_content = content.gsub(find, replace)
        else
          replacements = 1
          new_content = content.sub(find, replace)
        end

        File.write(resolved, new_content)

        success(path: params[:path], replacements: replacements)
      end
    end

    Registry.register("patch_file", PatchFile)
  end
end
