# frozen_string_literal: true

module Rubyn
  module Context
    class ContextBuilder
      MAX_CONTEXT_BYTES = 100_000
      AGENT_MAX_CONTEXT_BYTES = 500_000

      attr_reader :project_root

      def initialize(project_root = Dir.pwd, max_bytes: MAX_CONTEXT_BYTES)
        @project_root = project_root
        @max_bytes = max_bytes
      end

      def build(target_path, related_paths = [])
        context = {}
        total_size = 0

        all_paths = [target_path] + related_paths
        all_paths.uniq.each do |path|
          full_path = File.join(project_root, path)
          next unless File.exist?(full_path)

          content = File.read(full_path)
          break if total_size + content.bytesize > @max_bytes

          context[path] = content
          total_size += content.bytesize
        end

        context
      end
    end
  end
end
