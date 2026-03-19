# frozen_string_literal: true

module Rubyn
  class SpecsController < ApplicationController
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

      result = api_client.generate_spec(
        file_path: file_path,
        code: code,
        context_files: context_files,
        project_token: project_token
      )

      render json: result
    rescue Rubyn::Error => e
      render json: { error: e.message }, status: :unprocessable_entity
    end
  end
end
