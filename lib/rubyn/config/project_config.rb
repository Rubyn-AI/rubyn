# frozen_string_literal: true

require "yaml"
require "fileutils"

module Rubyn
  module Config
    class ProjectConfig
      CONFIG_DIR = ".rubyn"
      CONFIG_FILE = File.join(CONFIG_DIR, "project.yml")

      class << self
        def read(project_root = Dir.pwd)
          path = File.join(project_root, CONFIG_FILE)
          return {} unless File.exist?(path)

          YAML.safe_load_file(path) || {}
        end

        def write(data, project_root = Dir.pwd)
          dir = File.join(project_root, CONFIG_DIR)
          path = File.join(project_root, CONFIG_FILE)
          FileUtils.mkdir_p(dir)
          File.write(path, YAML.dump(data))
          data
        end

        def exists?(project_root = Dir.pwd)
          File.exist?(File.join(project_root, CONFIG_FILE))
        end

        def project_token(project_root = Dir.pwd)
          read(project_root)["project_token"]
        end

        def project_id(project_root = Dir.pwd)
          read(project_root)["project_id"]
        end
      end
    end
  end
end
