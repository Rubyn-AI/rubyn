# frozen_string_literal: true

require_relative "lib/rubyn/version"

Gem::Specification.new do |spec|
  spec.name = "rubyn"
  spec.version = Rubyn::VERSION
  spec.authors = ["matthewsuttles"]
  spec.email = ["matthewsuttles13@yahoo.com"]

  spec.summary = "Your Ruby & Rails Companion"
  spec.description = "AI-powered CLI and mountable Rails engine for refactoring, " \
                     "spec generation, code review, and conversational coding assistance."
  spec.homepage = "https://rubyn.dev"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.7"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/rubyn-dev/rubyn"
  spec.metadata["changelog_uri"] = "https://github.com/rubyn-dev/rubyn/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore .rspec spec/ .rubocop.yml .rubyn/ docs/])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "faraday", ">= 1.0", "< 3.0"
  spec.add_dependency "faraday-multipart", "~> 1.0"
  spec.add_dependency "pastel", ">= 0.8", "< 1.0"
  spec.add_dependency "rouge", ">= 3.0", "< 5.0"
  spec.add_dependency "sinatra", ">= 3.0", "< 5.0"
  spec.add_dependency "thor", ">= 1.0", "< 2.0"
  spec.add_dependency "tty-prompt", ">= 0.23", "< 1.0"
  spec.add_dependency "tty-spinner", ">= 0.9", "< 1.0"

  spec.add_development_dependency "dotenv", ">= 2.0", "< 4.0"
  spec.add_development_dependency "rails", ">= 6.0", "< 9.0"
  spec.add_development_dependency "rspec-rails", ">= 5.0", "< 8.0"
  spec.add_development_dependency "simplecov", "~> 0.22"
  spec.add_development_dependency "vcr", "~> 6.0"
  spec.add_development_dependency "webmock", "~> 3.0"
end
