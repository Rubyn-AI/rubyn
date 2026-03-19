# frozen_string_literal: true

require_relative "boot"
require "rails"
require "action_controller/railtie"
require "action_view/railtie"

Bundler.require(*Rails.groups)
require "rubyn"
require "rubyn/engine/engine"

module Dummy
  class Application < Rails::Application
    config.load_defaults Rails::VERSION::STRING.to_f
    config.eager_load = false
    config.hosts.clear
    config.secret_key_base = "test-secret-key-base-for-rubyn-specs"
    config.root = File.expand_path("../..", __FILE__)
  end
end
