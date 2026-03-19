# frozen_string_literal: true

require "digest"
require "yaml"
require "fileutils"

module Rubyn
  module Context
    class CodebaseIndexer
      CACHE_FILE = ".rubyn/index_cache.yml"
      BATCH_SIZE = 50

      attr_reader :project_root

      def initialize(project_root = Dir.pwd)
        @project_root = project_root
      end

      # Yields progress events: { phase:, current:, total:, file:, message: }
      def index(force: false, &on_progress)
        ruby_files = find_ruby_files
        cache = force ? {} : load_cache
        changed_files = detect_changes(ruby_files, cache)

        if changed_files.empty?
          report(on_progress, phase: :complete, message: "Everything up to date")
          return { indexed: 0, skipped: ruby_files.size, chunks: 0 }
        end

        report(on_progress, phase: :scan, message: "Found #{changed_files.size} files to analyse")

        result = process_changed_files(changed_files, cache, on_progress)

        report(on_progress, phase: :upload,
                            message: "Uploading #{result[:files].size} files in #{batch_count(result[:files])} batches")

        send_files(result[:files], on_progress)
        save_cache(result[:cache])

        report(on_progress, phase: :complete,
                            message: "Analysed #{changed_files.size} files")

        { indexed: changed_files.size, skipped: ruby_files.size - changed_files.size }
      end

      private

      def process_changed_files(changed_files, cache, on_progress = nil)
        all_files = []
        new_cache = cache.dup

        changed_files.each_with_index do |file, idx|
          report(on_progress, phase: :chunk, current: idx + 1, total: changed_files.size, file: file)

          content = File.read(File.join(project_root, file))
          file_hash = Digest::SHA256.hexdigest(content)
          all_files << { file_path: file, content: content, file_hash: file_hash }
          new_cache[file] = file_hash
        end

        { files: all_files, cache: new_cache }
      end

      def chunk_file(file_path, content)
        lines = content.lines
        chunks = parse_chunks(file_path, lines)

        if chunks.empty?
          chunks << default_chunk(file_path, content, lines)
        end

        chunks
      end

      def parse_chunks(file_path, lines)
        chunks = []
        current_chunk = nil
        current_start = nil
        nesting = 0

        lines.each_with_index do |line, index|
          line_num = index + 1

          if line.match?(/^\s*(class|module)\s+/)
            finalize_chunk(chunks, current_chunk, file_path, current_start, line_num - 1) if current_chunk
            current_chunk, current_start, nesting = start_class_or_module_chunk(line, line_num)
          elsif line.match?(/^\s*def\s+/) && nesting <= 1
            current_chunk, current_start = start_method_chunk(line, line_num, chunks, current_chunk, current_start, file_path)
          else
            current_chunk[:lines] << line if current_chunk

            if line.match?(/\b(do|begin)\b/) || (line.match?(/\bclass\b|\bmodule\b|\bdef\b/) && !line.match?(/end/))
              nesting += 1
            end
            nesting -= 1 if line.strip == "end"
          end
        end

        finalize_chunk(chunks, current_chunk, file_path, current_start, lines.size) if current_chunk
        chunks
      end

      def start_class_or_module_chunk(line, line_num)
        match = line.match(/^\s*(class|module)\s+(\S+)/)
        chunk = { type: match[1], name: match[2], lines: [line] }
        [chunk, line_num, 1]
      end

      def start_method_chunk(line, line_num, chunks, current_chunk, current_start, file_path)
        if current_chunk && current_chunk[:type] == "method"
          finalize_chunk(chunks, current_chunk, file_path, current_start, line_num - 1)
        end

        match = line.match(/^\s*def\s+(\S+)/)
        method_chunk = { type: "method", name: match[1], lines: [line] }

        if current_chunk.nil?
          [method_chunk, line_num]
        else
          current_chunk[:lines] << line
          [current_chunk, current_start]
        end
      end

      def default_chunk(file_path, content, lines)
        {
          file_path: file_path,
          chunk_type: "file",
          chunk_name: File.basename(file_path, ".rb"),
          chunk_content: content,
          line_start: 1,
          line_end: lines.size
        }
      end

      def report(callback, **data)
        callback&.call(data)
      end

      def batch_count(chunks)
        (chunks.size.to_f / BATCH_SIZE).ceil
      end

      def finalize_chunk(chunks, chunk, file_path, start_line, end_line)
        return unless chunk

        chunks << {
          file_path: file_path,
          chunk_type: chunk[:type],
          chunk_name: chunk[:name],
          chunk_content: chunk[:lines].join,
          line_start: start_line,
          line_end: end_line
        }
      end

      def find_ruby_files
        Dir.glob(File.join(project_root, "**/*.rb"))
           .reject { |f| f.include?("/vendor/") || f.include?("/node_modules/") || f.include?("/.rubyn/") }
           .map { |f| f.sub("#{project_root}/", "") }
      end

      def detect_changes(files, cache)
        files.reject do |file|
          full_path = File.join(project_root, file)
          current_hash = Digest::SHA256.hexdigest(File.read(full_path))
          cache[file] == current_hash
        end
      end

      def load_cache
        path = File.join(project_root, CACHE_FILE)
        return {} unless File.exist?(path)

        YAML.safe_load_file(path) || {}
      end

      def save_cache(cache)
        path = File.join(project_root, CACHE_FILE)
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, YAML.dump(cache))
      end

      def send_files(files, on_progress = nil)
        project_token = Rubyn::Config::ProjectConfig.project_token
        batches = files.each_slice(BATCH_SIZE).to_a

        batches.each_with_index do |batch, idx|
          report(on_progress, phase: :upload_batch, current: idx + 1, total: batches.size)
          Rubyn.api_client.index_project(project_token: project_token, files: batch)
        end
      end
    end
  end
end
