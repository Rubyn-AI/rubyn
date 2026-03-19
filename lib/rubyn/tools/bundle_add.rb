# frozen_string_literal: true

require "open3"
require_relative "base_tool"
require_relative "registry"

module Rubyn
  module Tools
    class BundleAdd < BaseTool
      DESCRIPTION = "Add a gem to the Gemfile and run bundle install"
      PARAMETERS = {
        gem_name: { type: :string, description: "Name of the gem to add", required: true },
        version: { type: :string, description: "Version constraint (e.g. ~> 2.0)", required: false },
        group: { type: :string, description: "Gemfile group (e.g. development, test)", required: false }
      }.freeze
      REQUIRES_CONFIRMATION = true

      def execute(params)
        gem_name = params[:gem_name]
        return error("gem_name is required") unless gem_name && !gem_name.strip.empty?

        gemfile_path = File.join(project_root, "Gemfile")
        return error("Gemfile not found in project root") unless File.exist?(gemfile_path)

        gem_line = build_gem_line(gem_name, params[:version])
        group = params[:group]

        begin
          gemfile_content = File.read(gemfile_path)

          gemfile_content = if group && !group.strip.empty?
                              insert_into_group(gemfile_content, group, gem_line)
                            else
                              "#{gemfile_content.rstrip}\n#{gem_line}\n"
                            end

          File.write(gemfile_path, gemfile_content)
        rescue StandardError => e
          return error("Failed to update Gemfile: #{e.message}")
        end

        begin
          stdout, stderr, status = Open3.capture3("bundle install", chdir: project_root)
        rescue StandardError => e
          return error("Failed to run bundle install: #{e.message}")
        end

        return error("bundle install failed: #{stderr}") unless status.exitstatus.zero?

        success(gem_name: gem_name, output: stdout)
      end

      private

      def build_gem_line(gem_name, version)
        if version && !version.strip.empty?
          "gem \"#{gem_name}\", \"#{version}\""
        else
          "gem \"#{gem_name}\""
        end
      end

      def insert_into_group(content, group, gem_line)
        group_pattern = /^group\s+:#{Regexp.escape(group)}.*?\bdo\b/
        if content.match?(group_pattern)
          content.sub(group_pattern) do |match|
            "#{match}\n  #{gem_line}"
          end
        else
          "#{content.rstrip}\n\ngroup :#{group} do\n  #{gem_line}\nend\n"
        end
      end
    end

    Registry.register("bundle_add", BundleAdd)
  end
end
