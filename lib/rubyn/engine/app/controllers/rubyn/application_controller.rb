# frozen_string_literal: true

module Rubyn
  class ApplicationController < ActionController::Base
    layout "rubyn/application"

    protect_from_forgery with: :null_session

    before_action :check_for_gem_update

    private

    def check_for_gem_update
      @update_message = Rubyn::VersionChecker.update_message
    rescue Rubyn::Error, Net::HTTPError, SocketError, Timeout::Error
      @update_message = nil
    end

    def api_client
      @api_client ||= Rubyn.api_client
    end

    def project_config
      @project_config ||= Config::ProjectConfig.read
    end

    def project_id
      project_config["project_id"]
    end

    def project_token
      project_config["project_token"]
    end

    def build_context_files(file_path)
      resolver = Context::FileResolver.new(Rails.root.to_s)
      related = resolver.resolve(file_path)
      builder = Context::ContextBuilder.new(Rails.root.to_s)
      context = builder.build(file_path, related)
      context.reject { |path, _| path == file_path }
             .map { |path, content| { file_path: path, code: content } }
    end
  end
end
