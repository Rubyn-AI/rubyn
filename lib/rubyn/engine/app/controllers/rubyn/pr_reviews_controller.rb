# frozen_string_literal: true

module Rubyn
  class PrReviewsController < ApplicationController
    def show
      @diff_info = begin
        differ = Git::BranchDiff.new(Rails.root.to_s)
        differ.diff
      rescue Rubyn::GitError => e
        { error: e.message }
      end
    end

    def create
      base = params[:base].presence

      differ = Git::BranchDiff.new(Rails.root.to_s)
      diff_result = differ.diff(base: base)

      if diff_result[:files].empty?
        render json: { error: "No changes detected" }, status: :unprocessable_entity
        return
      end

      changed_paths = diff_result[:files].map { |f| f[:path] }

      files = diff_result[:files]
                .reject { |f| f[:status] == "deleted" || f[:status] == "binary" }
                .map { |f| { file_path: f[:path], code: f[:content], diff: f[:diff] } }

      context_files = changed_paths
                        .flat_map { |path| build_context_files(path) }
                        .uniq { |ctx| ctx[:file_path] }
                        .reject { |ctx| changed_paths.include?(ctx[:file_path]) }

      result = api_client.pr_review(
        files: files,
        context_files: context_files,
        diffs: diff_result[:summary],
        base_branch: diff_result[:base_branch],
        project_token: project_token
      )

      render json: result
    rescue Rubyn::GitError => e
      render json: { error: e.message }, status: :unprocessable_entity
    rescue Rubyn::Error => e
      render json: { error: e.message }, status: :unprocessable_entity
    end
  end
end
