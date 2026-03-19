# frozen_string_literal: true

require "yaml"
require "fileutils"

module Rubyn
  module Config
    class Credentials
      CREDENTIALS_DIR = File.expand_path("~/.rubyn")
      CREDENTIALS_FILE = File.join(CREDENTIALS_DIR, "credentials")

      class << self
        def api_key
          ENV["RUBYN_API_KEY"] || read_credentials["api_key"]
        end

        def store(api_key:)
          FileUtils.mkdir_p(CREDENTIALS_DIR)
          data = read_credentials.merge("api_key" => api_key)
          File.write(CREDENTIALS_FILE, YAML.dump(data))
          File.chmod(0o600, CREDENTIALS_FILE)
          data
        end

        def exists?
          !api_key.nil? && !api_key.empty?
        end

        private

        def read_credentials
          return {} unless File.exist?(CREDENTIALS_FILE)

          YAML.safe_load_file(CREDENTIALS_FILE) || {}
        end
      end
    end
  end
end
