# frozen_string_literal: true

module Rubyn
  module Context
    class FileResolver
      attr_reader :project_root, :project_type

      def initialize(project_root = Dir.pwd, project_type: nil)
        @project_root = project_root
        @project_type = project_type || detect_project_type
      end

      def resolve(file_path)
        relative_path = file_path.start_with?(project_root) ? file_path.sub("#{project_root}/", "") : file_path

        related = case @project_type
                  when "rails_app"
                    resolve_rails(relative_path)
                  when "ruby_app"
                    resolve_ruby_gem(relative_path)
                  else
                    resolve_generic(relative_path)
                  end

        related.select { |f| File.exist?(File.join(project_root, f)) }.uniq
      end

      private

      def detect_project_type
        if File.exist?(File.join(project_root, "config", "routes.rb"))
          "rails_app"
        elsif Dir.glob(File.join(project_root, "*.gemspec")).any?
          "ruby_app"
        else
          "other_app"
        end
      end

      def resolve_rails(path)
        related = []

        case path
        when %r{^app/controllers/(.+)_controller\.rb$}
          name = Regexp.last_match(1)
          singular = singularize(File.basename(name))
          related += controller_related(name, singular)
        when %r{^app/models/(.+)\.rb$}
          name = Regexp.last_match(1)
          related += model_related(name)
        when %r{^app/services/(.+)\.rb$}
          name = Regexp.last_match(1)
          related += service_related(name, path)
        when %r{^spec/(.+)_spec\.rb$}
          source = Regexp.last_match(1)
          related << source_from_spec(source)
        end

        # Always scan for constant references to find dependencies
        related += resolve_constants(path)

        related << "config/routes.rb"
        related << "db/schema.rb"
        related
      end

      def controller_related(name, singular)
        [
          "app/models/#{singular}.rb",
          "config/routes.rb",
          "spec/requests/#{name}_spec.rb",
          "spec/controllers/#{name}_controller_spec.rb"
        ] + Dir.glob(File.join(project_root, "app/services/#{name}/**/*.rb")).map { |f| f.sub("#{project_root}/", "") }
      end

      def model_related(name)
        plural = pluralize(name)
        [
          "db/schema.rb",
          "app/controllers/#{plural}_controller.rb",
          "spec/models/#{name}_spec.rb",
          "spec/factories/#{plural}.rb",
          "spec/factories/#{name}.rb"
        ]
      end

      def service_related(name, path)
        related = ["spec/services/#{name}_spec.rb"]
        related + resolve_constants(path)
      end

      def resolve_ruby_gem(path)
        related = []

        case path
        when %r{^lib/(.+)\.rb$}
          spec_path = "spec/#{Regexp.last_match(1)}_spec.rb"
          related << spec_path

          dir = File.dirname(path)
          if dir != "lib"
            Dir.glob(File.join(project_root, dir, "*.rb")).each do |f|
              sibling = f.sub("#{project_root}/", "")
              related << sibling unless sibling == path
            end
          end
        when %r{^spec/(.+)_spec\.rb$}
          related << "lib/#{Regexp.last_match(1)}.rb"
        end

        related
      end

      def resolve_generic(path)
        dir = File.dirname(path)
        related = Dir.glob(File.join(project_root, dir, "*.rb")).map { |f| f.sub("#{project_root}/", "") }
        related.reject { |f| f == path }
      end

      def source_from_spec(spec_path)
        case spec_path
        when %r{^requests/(.+)$}
          "app/controllers/#{Regexp.last_match(1)}_controller.rb"
        when %r{^models/(.+)$}
          "app/models/#{Regexp.last_match(1)}.rb"
        when %r{^services/(.+)$}
          "app/services/#{Regexp.last_match(1)}.rb"
        else
          "lib/#{spec_path}.rb"
        end
      end

      # Scan a file for class/module constant references and locate their source files
      # in the project. Handles namespaced constants like Ai::ClaudeClient -> app/services/ai/claude_client.rb
      # Also parses Rails associations (belongs_to, has_many, has_one) to find related models.
      def resolve_constants(path)
        full_path = File.join(project_root, path)
        return [] unless File.exist?(full_path)

        content = File.read(full_path)
        found = []

        # Match namespaced constants: Foo::Bar::Baz, Foo::Bar, or standalone Foo
        # Excludes common Ruby/Rails constants that aren't project classes
        constants = content.scan(/\b([A-Z][a-zA-Z0-9]*(?:::[A-Z][a-zA-Z0-9]*)*)/).flatten.uniq
        constants -= ruby_stdlib_constants

        # Parse Rails associations to find related models
        # belongs_to :user -> User, has_many :line_items -> LineItem, has_one :profile -> Profile
        content.scan(/(?:belongs_to|has_one|has_many|has_and_belongs_to_many)\s+:(\w+)/).flatten.each do |assoc_name|
          # Singularize has_many names, then camelize
          model_name = singularize(assoc_name)
          constants << camelize(model_name)
        end

        constants.uniq!

        constants.each do |const|
          # Convert Foo::Bar::Baz to foo/bar/baz
          const_path = const.split("::").map { |part| underscore(part) }.join("/")

          # Search common Rails locations
          candidates = [
            "app/models/#{const_path}.rb",
            "app/services/#{const_path}.rb",
            "app/controllers/#{const_path}_controller.rb",
            "app/jobs/#{const_path}.rb",
            "app/mailers/#{const_path}.rb",
            "app/forms/#{const_path}.rb",
            "app/queries/#{const_path}.rb",
            "app/policies/#{const_path}.rb",
            "app/serializers/#{const_path}.rb",
            "app/validators/#{const_path}.rb",
            "app/workers/#{const_path}.rb",
            "lib/#{const_path}.rb"
          ]

          candidates.each do |candidate|
            if File.exist?(File.join(project_root, candidate)) && candidate != path
              found << candidate
            end
          end
        end

        found.uniq
      end

      # Common Ruby/Rails constants to ignore when scanning for project dependencies
      def ruby_stdlib_constants
        @ruby_stdlib_constants ||= %w[
          String Integer Float Array Hash Symbol Regexp Range IO File Dir
          Time Date DateTime Numeric Boolean Object Class Module Kernel
          Struct OpenStruct Comparable Enumerable Enumerator Proc Lambda
          Set SortedSet Queue Thread Mutex Process Signal Fiber
          StandardError RuntimeError ArgumentError TypeError NameError
          NoMethodError NotImplementedError IOError Errno
          ActiveRecord ActiveModel ActiveSupport ActionController ActionView
          ActionMailer ActiveJob ActionCable ApplicationRecord ApplicationController
          ApplicationMailer ApplicationJob ActiveStorage ActionText
          Rails Rake Bundler Gem RSpec Minitest FactoryBot
          Logger JSON YAML CSV ERB URI Net HTTP HTTPS
          Base64 Digest OpenSSL SecureRandom Pathname Tempfile
          BigDecimal Complex Rational
          TRUE FALSE NIL ENV ARGV STDIN STDOUT STDERR
          Grape API
        ]
      end

      def singularize(word)
        return word[0..-4] if word.end_with?("ies")
        return word[0..-3] if word.end_with?("ses")
        return word[0..-2] if word.end_with?("s")

        word
      end

      def pluralize(word)
        return "#{word[0..-2]}ies" if word.end_with?("y") && !word.end_with?("ey")
        return "#{word}es" if word.end_with?("s", "x", "z", "ch", "sh")

        "#{word}s"
      end

      def camelize(underscored)
        underscored.split("_").map(&:capitalize).join
      end

      def underscore(camel)
        camel.gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
             .gsub(/([a-z\d])([A-Z])/, '\1_\2')
             .downcase
      end
    end
  end
end
