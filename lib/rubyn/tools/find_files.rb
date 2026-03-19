# frozen_string_literal: true

module Rubyn
  module Tools
    class FindFiles < BaseTool
      DESCRIPTION = "Find files matching a glob pattern"
      PARAMETERS = {
        pattern: { type: "string", required: true, description: "Glob pattern (e.g. 'app/models/**/*.rb')" }
      }.freeze
      REQUIRES_CONFIRMATION = false

      MAX_RESULTS = 200

      def execute(params)
        pattern = params[:pattern]
        return error("Missing required parameter: pattern") unless pattern

        glob_path = File.join(project_root, pattern)
        all_files = Dir.glob(glob_path, File::FNM_DOTMATCH)

        files = all_files
                .reject { |f| excluded?(f) }
                .select { |f| File.file?(f) }
                .first(MAX_RESULTS)
                .map { |f| relative_path(f) }

        success(pattern: pattern, files: files, count: files.size)
      end
    end
  end
end

Rubyn::Tools::Registry.register("find_files", Rubyn::Tools::FindFiles)
