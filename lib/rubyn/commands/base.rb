# frozen_string_literal: true

module Rubyn
  module Commands
    class Base
      private

      # Full check: credentials + project config (used by most commands)
      def ensure_configured!
        return if Rubyn::Config::Credentials.exists? && Rubyn::Config::ProjectConfig.exists?

        Rubyn::Output::Formatter.error("Not configured. Run `rubyn init` first.")
        raise Rubyn::ConfigurationError, "Not configured"
      end

      # Auto-index codebase if user has Pro/Lifetime but hasn't indexed yet
      # def auto_index_if_needed!
      #   result = Rubyn.api_client.verify_auth
      #   return unless result.dig("user", "needs_indexing")
      #
      #   formatter = Rubyn::Output::Formatter
      #   formatter.info("Pro feature unlocked — indexing your codebase for enhanced context...")
      #   formatter.newline
      #
      #   indexer = Rubyn::Context::CodebaseIndexer.new
      #   indexer.index
      #   formatter.success("Codebase indexed! Your AI commands now include project context.")
      #   formatter.newline
      # rescue Rubyn::Error => e
      #   Rubyn::Output::Formatter.warning("Auto-indexing skipped: #{e.message}")
      # end
      def auto_index_if_needed!; end

      # Credentials-only check (used by usage command)
      def ensure_credentials!
        return if Rubyn::Config::Credentials.exists?

        Rubyn::Output::Formatter.error("Not configured. Run `rubyn init` first.")
        raise Rubyn::ConfigurationError, "Not configured"
      end

      def relative_to_project(file)
        File.expand_path(file).sub("#{Dir.pwd}/", "")
      end

      def build_context_files(relative_path)
        resolver = Rubyn::Context::FileResolver.new
        related = resolver.resolve(relative_path)
        builder = Rubyn::Context::ContextBuilder.new
        context = builder.build(relative_path, related)
        context.reject { |path, _| path == relative_path }
               .map { |path, content| { file_path: path, code: content } }
      end

      def project_token
        Rubyn::Config::ProjectConfig.project_token
      end
    end
  end
end
