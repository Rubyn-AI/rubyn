# frozen_string_literal: true

module Rubyn
  module Tools
    class ListDirectory < BaseTool
      DESCRIPTION = "List files and directories at a given path"
      PARAMETERS = {
        path: { type: "string", required: false, description: "Directory path (defaults to project root)" },
        recursive: { type: "boolean", required: false, description: "List recursively (default false)" }
      }.freeze
      REQUIRES_CONFIRMATION = false

      MAX_ENTRIES = 500

      def execute(params)
        target_path = params[:path] || "."
        recursive = params[:recursive] || false

        resolved = resolve_path(target_path)
        return resolved if resolved.is_a?(Hash) && resolved[:error]

        return error("Directory not found: #{target_path}") unless Dir.exist?(resolved)

        entries = if recursive
                    list_recursive(resolved)
                  else
                    list_flat(resolved)
                  end

        success(path: relative_path(resolved), entries: entries)
      end

      private

      def list_flat(dir)
        entries = []
        Dir.children(dir).sort.each do |name|
          break if entries.size >= MAX_ENTRIES

          next if excluded?(name)

          full = File.join(dir, name)
          entries << entry_info(name, full)
        end
        entries
      end

      def list_recursive(dir, prefix: "")
        entries = []
        Dir.children(dir).sort.each do |name|
          return entries if entries.size >= MAX_ENTRIES

          next if excluded?(name)

          full = File.join(dir, name)
          rel = prefix.empty? ? name : File.join(prefix, name)

          entries << entry_info(rel, full)

          entries.concat(list_recursive(full, prefix: rel)) if File.directory?(full)
        end
        entries
      end

      def entry_info(name, full_path)
        if File.directory?(full_path)
          { name: name, type: "directory", size: 0 }
        else
          { name: name, type: "file", size: File.size(full_path) }
        end
      rescue SystemCallError
        { name: name, type: "unknown", size: 0 }
      end

      def excluded?(name)
        EXCLUDED_DIRS.any? { |ex| name == ex || name.start_with?("#{ex}/") }
      end
    end
  end
end

Rubyn::Tools::Registry.register("list_directory", Rubyn::Tools::ListDirectory)
