# frozen_string_literal: true

require "yaml"
require "fileutils"

module Rubyn
  module Config
    class Settings
      SETTINGS_DIR = File.expand_path("~/.rubyn")
      SETTINGS_FILE = File.join(SETTINGS_DIR, "config.yml")

      DEFAULTS = {
        "default_model" => "haiku",
        "auto_apply" => false,
        "output_format" => "diff"
      }.freeze

      class << self
        def get(key)
          all[key.to_s]
        end

        def set(key, value)
          data = all.merge(key.to_s => coerce_value(value))
          FileUtils.mkdir_p(SETTINGS_DIR)
          File.write(SETTINGS_FILE, YAML.dump(data))
          data
        end

        def all
          DEFAULTS.merge(read_settings)
        end

        private

        def read_settings
          return {} unless File.exist?(SETTINGS_FILE)

          YAML.safe_load_file(SETTINGS_FILE) || {}
        end

        def coerce_value(value)
          case value
          when "true" then true
          when "false" then false
          when /\A\d+\z/ then value.to_i
          else value
          end
        end
      end
    end
  end
end
