# frozen_string_literal: true

module Rubyn
  class RefactorController < ApplicationController
    def show
      @file = params[:file]
    end

    def create
      file_path = params[:file]
      full_path = Rails.root.join(file_path)

      unless File.exist?(full_path)
        render json: { error: "File not found: #{file_path}" }, status: :not_found
        return
      end

      code = File.read(full_path)
      context_files = build_context_files(file_path)

      result = api_client.refactor(
        file_path: file_path,
        code: code,
        context_files: context_files,
        project_token: project_token
      )

      render json: result
    rescue Rubyn::Error => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    def update
      file_path = params[:file]
      code = params[:code]

      unless file_path.present? && code.present?
        render json: { error: "Missing file path or code" }, status: :bad_request
        return
      end

      full_path = Rails.root.join(file_path)

      # Create directories for new files (e.g., app/services/orders/)
      FileUtils.mkdir_p(File.dirname(full_path))

      created = !File.exist?(full_path)
      File.write(full_path, code)

      action = created ? "Created" : "Updated"
      render json: { success: true, message: "#{action} #{file_path}" }
    rescue Errno::EACCES, Errno::ENOENT, Errno::ENOSPC => e
      render json: { error: e.message }, status: :unprocessable_entity
    end
  end
end
