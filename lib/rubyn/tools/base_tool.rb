# frozen_string_literal: true

require "yaml"

module Rubyn
  module Tools
    class BaseTool
      attr_reader :project_root

      DESCRIPTION = "Base tool"
      PARAMETERS = {}.freeze
      REQUIRES_CONFIRMATION = false

      def initialize(project_root = Dir.pwd)
        @project_root = project_root
      end

      def call(raw_params)
        params = self.class.symbolize_params(raw_params)
        execute(params)
      end

      def execute(params)
        raise NotImplementedError, "#{self.class}#execute must be implemented"
      end

      def requires_confirmation?
        self.class::REQUIRES_CONFIRMATION
      end

      # Normalize string keys to symbol keys so tools can use params[:key]
      def self.symbolize_params(params)
        return {} unless params.is_a?(Hash)

        params.each_with_object({}) do |(k, v), h|
          h[k.to_sym] = v
        end
      end

      EXCLUDED_DIRS = %w[.git node_modules vendor/bundle vendor tmp].freeze
      DEFAULT_MAX_OUTPUT_LENGTH = 10_000

      BLOCKED_FILES = %w[
        config/master.key
        config/credentials.yml.enc
        config/credentials
      ].freeze

      SENSITIVE_FILES = %w[
        .env
      ].freeze

      SECURITY_CONFIG_FILE = File.join(".rubyn", "security.yml").freeze

      private

      def excluded?(path)
        rel = relative_path(path)
        EXCLUDED_DIRS.any? { |dir| rel.start_with?("#{dir}/") || rel.include?("/#{dir}/") }
      end

      def truncate_output(output, max_length = self.class::DEFAULT_MAX_OUTPUT_LENGTH)
        return output if output.length <= max_length

        output[0...max_length] + "\n... (truncated, #{output.length} total chars)"
      end

      def resolve_path(path)
        expanded = File.expand_path(path, project_root)
        return error("Access denied: path is outside project root") unless expanded.start_with?(project_root)

        rel = expanded.sub("#{project_root}/", "")
        return error("Access denied: #{rel} is a protected file") if blocked_file?(rel)

        expanded
      end

      def blocked_file?(relative_path)
        all_blocked = BLOCKED_FILES + security_config("blocked_files")
        matches_any?(relative_path, all_blocked)
      end

      def sensitive_file?(relative_path)
        all_sensitive = SENSITIVE_FILES + security_config("sensitive_files")
        matches_any?(relative_path, all_sensitive)
      end

      def matches_any?(relative_path, patterns)
        patterns.any? do |pattern|
          relative_path == pattern ||
            relative_path.start_with?("#{pattern}/") ||
            File.fnmatch?(pattern, relative_path, File::FNM_PATHNAME)
        end
      end

      def security_config(key)
        @security_config ||= load_security_config
        @security_config.fetch(key, [])
      end

      def load_security_config
        path = File.join(project_root, SECURITY_CONFIG_FILE)
        return {} unless File.exist?(path)

        YAML.safe_load_file(path) || {}
      rescue Psych::SyntaxError
        {}
      end

      def relative_path(full_path)
        full_path.sub("#{project_root}/", "")
      end

      def success(data)
        { success: true }.merge(data)
      end

      def error(message)
        { success: false, error: message }
      end
    end
  end
end
