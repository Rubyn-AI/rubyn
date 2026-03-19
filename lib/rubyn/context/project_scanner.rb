# frozen_string_literal: true

module Rubyn
  module Context
    class ProjectScanner
      attr_reader :project_root

      def initialize(project_root = Dir.pwd)
        @project_root = project_root
      end

      def scan
        {
          project_name: File.basename(project_root),
          project_type: detect_project_type,
          ruby_version: detect_ruby_version,
          rails_version: detect_rails_version,
          test_framework: detect_test_framework,
          factory_library: detect_factory_library,
          auth_library: detect_auth_library,
          gems: detect_gems,
          directory_structure: scan_directory_structure
        }
      end

      private

      def detect_project_type
        if File.exist?(File.join(project_root, "config", "routes.rb"))
          "rails_app"
        elsif File.exist?(File.join(project_root, "config.ru")) && gemfile_contains?("sinatra")
          "sinatra_app"
        elsif Dir.glob(File.join(project_root, "*.gemspec")).any?
          "ruby_app"
        else
          "other_app"
        end
      end

      def detect_ruby_version
        version_file = File.join(project_root, ".ruby-version")
        return File.read(version_file).strip if File.exist?(version_file)

        tool_versions = File.join(project_root, ".tool-versions")
        if File.exist?(tool_versions)
          match = File.read(tool_versions).match(/ruby\s+(\S+)/)
          return match[1] if match
        end

        nil
      end

      def detect_rails_version
        lockfile = lockfile_content
        return nil unless lockfile

        match = lockfile.match(/^\s+rails\s+\((\S+)\)/m)
        match ? match[1] : nil
      end

      def detect_test_framework
        lockfile = lockfile_content
        return "rspec" if lockfile&.include?("rspec")
        return "rspec" if Dir.exist?(File.join(project_root, "spec"))
        return "minitest" if Dir.exist?(File.join(project_root, "test"))

        "rspec"
      end

      def detect_factory_library
        lockfile = lockfile_content
        return "factory_bot" if lockfile&.include?("factory_bot")
        return "fabrication" if lockfile&.include?("fabrication")

        "no_factory"
      end

      def detect_auth_library
        lockfile = lockfile_content
        return "devise" if lockfile&.include?("devise")
        return "clearance" if lockfile&.include?("clearance")

        nil
      end

      def detect_gems
        lockfile = lockfile_content
        return [] unless lockfile

        gems = []
        in_specs = false
        lockfile.each_line do |line|
          if line.strip == "specs:"
            in_specs = true
            next
          end
          break if in_specs && !line.start_with?("  ")

          if in_specs
            match = line.match(/^\s{4}(\S+)\s+\((\S+)\)/)
            gems << { name: match[1], version: match[2] } if match
          end
        end
        gems
      end

      def scan_directory_structure
        dirs = %w[app lib spec test config db]
        structure = {}
        dirs.each do |dir|
          full_path = File.join(project_root, dir)
          structure[dir] = Dir.exist?(full_path)
        end
        structure
      end

      def gemfile_contains?(gem_name)
        gemfile = File.join(project_root, "Gemfile")
        return false unless File.exist?(gemfile)

        File.read(gemfile).include?(gem_name)
      end

      def lockfile_content
        @lockfile_content ||= begin
          path = File.join(project_root, "Gemfile.lock")
          File.exist?(path) ? File.read(path) : nil
        end
      end
    end
  end
end
