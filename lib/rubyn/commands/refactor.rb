# frozen_string_literal: true

require "fileutils"

module Rubyn
  module Commands
    class Refactor < Base
      def execute(file)
        formatter = Rubyn::Output::Formatter
        ensure_configured!
        auto_index_if_needed!

        unless File.exist?(file)
          formatter.error("File not found: #{file}")
          return
        end

        file_content = File.read(file)
        relative_path = relative_to_project(file)
        formatted_context = build_context_files(relative_path)

        formatter.info("Analyzing #{File.basename(file)}...")
        formatter.info("Context: #{formatted_context.size} related file(s)")
        formatter.newline
        begin
          result = Rubyn.api_client.refactor(
            file_path: relative_path,
            code: file_content,
            context_files: formatted_context,
            project_token: project_token
          )

          full_response = result["response"] || ""
          formatter.print_content(full_response)
          formatter.newline
          formatter.credit_usage(result["credits_used"], nil) if result["credits_used"]
          formatter.newline
          prompt_apply(file, file_content, full_response, formatter)
        rescue Rubyn::AuthenticationError => e
          formatter.error("Authentication failed: #{e.message}")
        rescue Rubyn::APIError => e
          formatter.error(e.message)
        end
      end

      private

      def prompt_apply(file, original, response, formatter)
        file_blocks = extract_file_blocks(response)
        return if file_blocks.empty?

        if file_blocks.length == 1 && file_blocks.first[:tag].nil?
          prompt_apply_single(file, original, file_blocks.first[:code], formatter)
        else
          prompt_apply_multi(file, original, file_blocks, formatter)
        end
      end

      def extract_file_blocks(response)
        blocks = []

        # Split response around code blocks, keeping surrounding text for path detection
        parts = response.split(/(```ruby\n.*?```)/m)

        parts.each_with_index do |part, i|
          next unless part.start_with?("```ruby\n")

          code = part.sub(/\A```ruby\n/, "").sub(/```\z/, "")
          preceding_text = i > 0 ? parts[i - 1] : ""

          # Strategy 1: Path in bold header above code block
          # **New file: app/services/foo.rb** or **app/services/foo.rb**
          path = preceding_text.match(/\*\*(?:New file:\s*|Modified:\s*)?([a-zA-Z0-9_\/\.\-]+\.rb)\*\*/i)&.dig(1)

          # Strategy 2: Path as backtick-wrapped line above code block
          path ||= preceding_text.match(/`([a-zA-Z0-9_\/\.\-]+\.rb)`\s*\z/)&.dig(1)

          # Strategy 3: Path as comment on first line inside code block
          path ||= code.lines.first&.strip&.match(/^#\s*([a-zA-Z0-9_\/\.\-]+\.rb)/)&.dig(1)

          blocks << { path: path, code: code }
        end

        blocks
      end

      def prompt_apply_single(file, original, new_content, formatter)
        print "\nApply changes? (y/n/diff) "
        choice = $stdin.gets&.strip&.downcase

        case choice
        when "y"
          File.write(file, new_content)
          formatter.success("Changes applied to #{file}")
        when "diff"
          Rubyn::Output::DiffRenderer.render(original: original, modified: new_content)
          print "\nApply changes? (y/n) "
          if $stdin.gets&.strip&.downcase == "y"
            File.write(file, new_content)
            formatter.success("Changes applied to #{file}")
          else
            formatter.info("Changes discarded.")
          end
        else
          formatter.info("Changes discarded.")
        end
      end

      def prompt_apply_multi(file, original, file_blocks, formatter)
        formatter.newline
        formatter.info("This refactor produces #{file_blocks.length} file(s):")
        file_blocks.each do |block|
          path = block[:path] || file
          is_new = path != file && !path.end_with?("/#{file}") && !file.end_with?("/#{path}")
          label = is_new ? "NEW" : "MODIFIED"
          formatter.info("  [#{label}] #{path}")
        end

        print "\nApply all changes? (y/n/select) "
        choice = $stdin.gets&.strip&.downcase

        case choice
        when "y"
          apply_all_blocks(file, original, file_blocks, formatter)
        when "select"
          apply_selected_blocks(file, original, file_blocks, formatter)
        else
          formatter.info("All changes discarded.")
        end
      end

      def apply_all_blocks(file, original, file_blocks, formatter)
        file_blocks.each do |block|
          write_block(file, block, formatter)
        end
      end

      def apply_selected_blocks(file, original, file_blocks, formatter)
        file_blocks.each do |block|
          path = block[:path] || file
          is_new = path != file && !path.end_with?("/#{file}") && !file.end_with?("/#{path}")
          label = is_new ? "NEW" : "MODIFIED"
          print "  Apply [#{label}] #{path}? (y/n/diff) "
          choice = $stdin.gets&.strip&.downcase

          case choice
          when "y"
            write_block(file, block, formatter)
          when "diff"
            existing = is_new ? "" : File.read(resolve_path(file, block))
            Rubyn::Output::DiffRenderer.render(original: existing, modified: block[:code])
            print "  Apply? (y/n) "
            if $stdin.gets&.strip&.downcase == "y"
              write_block(file, block, formatter)
            else
              formatter.info("  Skipped #{path}")
            end
          else
            formatter.info("  Skipped #{path}")
          end
        end
      end

      def write_block(original_file, block, formatter)
        target = resolve_path(original_file, block)
        dir = File.dirname(target)
        FileUtils.mkdir_p(dir) unless File.directory?(dir)
        File.write(target, block[:code])
        label = block[:tag] == "NEW" ? "Created" : "Updated"
        formatter.success("#{label} #{target}")
      end

      def resolve_path(original_file, block)
        return original_file unless block[:path]

        if block[:path].start_with?("/")
          block[:path]
        else
          File.join(Dir.pwd, block[:path])
        end
      end
    end
  end
end
