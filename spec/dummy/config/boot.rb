# frozen_string_literal: true

# Point to the gem's Gemfile
ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../../../../Gemfile", __FILE__)
require "bundler/setup"

# Set RAILS root to spec/dummy before Rails loads
ENV["RAILS_ROOT"] = File.expand_path("../..", __FILE__)
