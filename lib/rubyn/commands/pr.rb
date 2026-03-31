# frozen_string_literal: true

module Rubyn
  module Commands
    class Pr < Base
      def execute(base: nil)
        formatter = Rubyn::Output::Formatter
        ensure_configured!

        formatter.header("PR Review")

        spinner = Rubyn::Output::Spinner.new
        spinner.start("Detecting changes...")

        begin
          diff_result = Rubyn::Git::BranchDiff.new.diff(base: base)
        rescue Rubyn::GitError => e
          spinner.stop_error("Failed")
          formatter.error(e.message)
          return
        end

        if diff_result[:files].empty?
          spinner.stop_success("Done")
          formatter.warning("No changes detected. Nothing to review.")
          return
        end

        spinner.stop_success("Found changes")
        display_change_summary(formatter, diff_result)

        files = build_review_files(diff_result[:files])
        context_files = build_review_context(diff_result[:files])
        diffs_summary = diff_result[:summary]

        formatter.info("Sending #{files.size} file(s) + #{context_files.size} context file(s) for review...")
        formatter.newline

        begin
          result = Rubyn.api_client.pr_review(
            files: files,
            context_files: context_files,
            diffs: diffs_summary,
            base_branch: diff_result[:base_branch],
            project_token: project_token
          )

          formatter.print_content(result["response"] || "")
          formatter.newline
          formatter.credit_usage(result["credits_used"], nil) if result["credits_used"]

          apply_suggestions(result["response"] || "", formatter)
        rescue Rubyn::AuthenticationError => e
          formatter.error("Authentication failed: #{e.message}")
        rescue Rubyn::APIError => e
          formatter.error(e.message)
        end
      end

      private

      def display_change_summary(formatter, diff_result)
        formatter.info("Base: #{diff_result[:base_branch]}")
        formatter.info(diff_result[:summary])
        formatter.newline

        diff_result[:files].each do |file|
          label = case file[:status]
                  when "added" then "  + #{file[:path]}"
                  when "deleted" then "  - #{file[:path]}"
                  when "renamed" then "  R #{file[:old_path]} -> #{file[:path]}"
                  when "binary" then "  B #{file[:path]}"
                  else "  M #{file[:path]}"
                  end
          formatter.info(label)
        end
        formatter.newline
      end

      def build_review_files(changed_files)
        changed_files
          .reject { |f| f[:status] == "deleted" || f[:status] == "binary" }
          .map { |f| { file_path: f[:path], code: f[:content], diff: f[:diff] } }
      end

      def build_review_context(changed_files)
        changed_paths = changed_files.map { |f| f[:path] }

        changed_paths
          .flat_map { |path| build_context_files(path) }
          .uniq { |ctx| ctx[:file_path] }
          .reject { |ctx| changed_paths.include?(ctx[:file_path]) }
      end

      def apply_suggestions(response, formatter)
        file_blocks = Context::ResponseParser.extract_file_blocks(response)
        return if file_blocks.empty?

        applier = Context::FileApplier.new(original_file: nil, formatter: formatter)
        applier.apply(file_blocks)
      end
    end
  end
end
