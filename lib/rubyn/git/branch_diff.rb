# frozen_string_literal: true

require "open3"

module Rubyn
  module Git
    class BranchDiff
      MAX_DIFF_BYTES = 15_000
      DEFAULT_BRANCHES = %w[main master].freeze

      attr_reader :project_root

      def initialize(project_root = Dir.pwd)
        @project_root = project_root
      end

      def diff(base: nil)
        ensure_git_repo!
        ensure_no_conflicts!

        base_ref = resolve_base(base)
        changed = collect_changed_files(base_ref)

        {
          base_branch: base_ref,
          files: changed,
          summary: build_summary(changed)
        }
      end

      private

      def ensure_git_repo!
        _, _, status = run_git("rev-parse", "--git-dir")
        raise Rubyn::GitError, "Not a git repository. Run `git init` first." unless status.success?
      end

      def ensure_no_conflicts!
        stdout, _, status = run_git("diff", "--check")
        return if status.success?
        return if stdout.strip.empty?

        raise Rubyn::GitError, "Merge conflicts detected. Resolve them before running PR review."
      end

      def resolve_base(base)
        return base if base && branch_exists?(base)
        raise Rubyn::GitError, "Base branch '#{base}' not found." if base

        detected = DEFAULT_BRANCHES.find { |b| branch_exists?(b) }
        return detected if detected

        # Fallback: use HEAD~1 if no default branch found (single-branch repo)
        _, _, status = run_git("rev-parse", "HEAD~1")
        return "HEAD~1" if status.success?

        raise Rubyn::GitError, "Could not detect base branch. Specify one with --base."
      end

      def branch_exists?(name)
        _, _, status = run_git("rev-parse", "--verify", name)
        status.success?
      end

      def collect_changed_files(base_ref)
        files_by_path = {}

        # Branch-level changes (committed)
        merge_base = find_merge_base(base_ref)
        if merge_base
          add_changes(files_by_path, diff_name_status("#{merge_base}..HEAD"), merge_base)
        end

        # Uncommitted staged changes
        add_changes(files_by_path, diff_name_status("--cached"), "HEAD")

        # Uncommitted unstaged changes
        add_changes(files_by_path, diff_name_status(nil), "HEAD")

        # Build full file entries
        binary_paths = detect_binary_files(merge_base || "HEAD")

        files_by_path.map do |path, info|
          build_file_entry(path, info, merge_base || "HEAD", binary_paths)
        end
      end

      def find_merge_base(base_ref)
        return nil if base_ref == "HEAD~1" && on_default_branch?

        stdout, _, status = run_git("merge-base", "HEAD", base_ref)
        status.success? ? stdout.strip : nil
      end

      def on_default_branch?
        stdout, _, status = run_git("rev-parse", "--abbrev-ref", "HEAD")
        return false unless status.success?

        DEFAULT_BRANCHES.include?(stdout.strip)
      end

      def diff_name_status(ref_range)
        args = ["diff", "--name-status"]
        args << ref_range if ref_range
        stdout, _, _ = run_git(*args)
        parse_name_status(stdout)
      end

      def parse_name_status(output)
        output.lines.filter_map do |line|
          parts = line.strip.split("\t")
          next if parts.size < 2

          status_code = parts[0]
          case status_code
          when "M"
            { path: parts[1], status: "modified" }
          when "A"
            { path: parts[1], status: "added" }
          when "D"
            { path: parts[1], status: "deleted" }
          when /\AR/
            { path: parts[2], status: "renamed", old_path: parts[1] }
          end
        end
      end

      def add_changes(files_by_path, changes, _ref)
        changes.each do |change|
          path = change[:path]
          next if path.nil? || path.empty?

          # Later sources (unstaged) override earlier (committed)
          files_by_path[path] = change
        end
      end

      def detect_binary_files(base_ref)
        stdout, _, _ = run_git("diff", "--numstat", "#{base_ref}..HEAD")
        binary = Set.new

        stdout.lines.each do |line|
          parts = line.strip.split("\t")
          # Binary files show "-" for additions and deletions
          binary.add(parts[2]) if parts[0] == "-" && parts[1] == "-" && parts[2]
        end

        # Also check staged/unstaged
        ["--cached", nil].each do |flag|
          args = ["diff", "--numstat"]
          args << flag if flag
          out, _, _ = run_git(*args)
          out.lines.each do |line|
            parts = line.strip.split("\t")
            binary.add(parts[2]) if parts[0] == "-" && parts[1] == "-" && parts[2]
          end
        end

        binary
      end

      def build_file_entry(path, info, base_ref, binary_paths)
        if binary_paths.include?(path)
          return { path: path, status: "binary", diff: nil, content: nil }
        end

        if info[:status] == "deleted"
          diff = file_diff(base_ref, path)
          return { path: path, status: "deleted", diff: diff, content: nil }
        end

        full_path = File.join(project_root, path)
        content = File.exist?(full_path) ? File.read(full_path) : nil
        diff = file_diff(base_ref, path)

        entry = { path: path, status: info[:status], diff: diff, content: content }
        entry[:old_path] = info[:old_path] if info[:old_path]
        entry
      end

      def file_diff(base_ref, path)
        stdout, _, _ = run_git("diff", base_ref, "--", path)

        # Also include uncommitted changes
        unstaged, _, _ = run_git("diff", "--", path)
        staged, _, _ = run_git("diff", "--cached", "--", path)

        combined = [stdout, staged, unstaged].reject { |s| s.strip.empty? }.join("\n")
        truncate_diff(combined)
      end

      def truncate_diff(diff)
        return diff if diff.bytesize <= MAX_DIFF_BYTES

        diff.byteslice(0, MAX_DIFF_BYTES) + "\n... (diff truncated, #{diff.bytesize} total bytes)"
      end

      def build_summary(files)
        return "No changes detected" if files.empty?

        by_status = files.group_by { |f| f[:status] }
        parts = []
        parts << "#{by_status["modified"]&.size || 0} modified" if by_status["modified"]
        parts << "#{by_status["added"]&.size || 0} added" if by_status["added"]
        parts << "#{by_status["deleted"]&.size || 0} deleted" if by_status["deleted"]
        parts << "#{by_status["renamed"]&.size || 0} renamed" if by_status["renamed"]
        parts << "#{by_status["binary"]&.size || 0} binary" if by_status["binary"]

        "#{files.size} file(s) changed: #{parts.join(", ")}"
      end

      def run_git(*args)
        Open3.capture3("git", *args, chdir: project_root)
      rescue Errno::ENOENT
        raise Rubyn::GitError, "git is not installed or not in PATH."
      end
    end
  end
end
