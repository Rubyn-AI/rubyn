# frozen_string_literal: true

module Rubyn
  class FilesController < ApplicationController
    CATEGORIES = {
      "Models" => "app/models/**/*.rb",
      "Controllers" => "app/controllers/**/*.rb",
      "Views" => "app/views/**/*.{erb,haml,slim}",
      "Helpers" => "app/helpers/**/*.rb",
      "Services" => "app/services/**/*.rb",
      "Query Objects" => "app/queries/**/*.rb",
      "Jobs" => "app/jobs/**/*.rb",
      "Mailers" => "app/mailers/**/*.rb",
      "Channels" => "app/channels/**/*.rb",
      "Serializers" => "app/serializers/**/*.rb",
      "Policies" => "app/policies/**/*.rb",
      "Lib" => "lib/**/*.rb",
      "Config" => "config/**/*.rb",
      "Specs" => "spec/**/*.rb",
      "Tests" => "test/**/*.rb"
    }.freeze

    def index
      all_files = scan_ruby_files
      @categories = categorize(all_files)
      @total_count = all_files.size
    end

    private

    def scan_ruby_files
      Dir.glob(File.join(Rails.root, "**/*.{rb,erb,haml,slim}"))
         .reject { |f| f.include?("/vendor/") || f.include?("/node_modules/") }
         .map { |f| f.sub("#{Rails.root}/", "") }
         .sort
    end

    def categorize(files)
      categorized = {}
      remaining = files.dup

      CATEGORIES.each do |label, pattern|
        matched = remaining.select { |f| File.fnmatch?(pattern, f, File::FNM_PATHNAME) }
        next if matched.empty?

        categorized[label] = matched
        remaining -= matched
      end

      categorized["Other"] = remaining if remaining.any?
      categorized
    end
  end
end
