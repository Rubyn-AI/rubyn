# frozen_string_literal: true

require "fileutils"

module Rubyn
  module Context
    class FileApplier
      def initialize(original_file:, formatter:)
        @original_file = original_file
        @formatter = formatter
      end

      def apply(file_blocks)
        if file_blocks.length == 1 && file_blocks.first[:path].nil?
          apply_single(file_blocks.first[:code])
        else
          apply_multi(file_blocks)
        end
      end

      private

      def apply_single(code)
        print "\nApply changes? (y/n/diff) "
        choice = $stdin.gets&.strip&.downcase

        case choice
        when "y"
          write_file(@original_file, code)
        when "diff"
          original_content = File.read(@original_file)
          Rubyn::Output::DiffRenderer.render(original: original_content, modified: code)
          print "\nApply changes? (y/n) "
          write_file(@original_file, code) if $stdin.gets&.strip&.downcase == "y"
        else
          @formatter.info("Changes discarded.")
        end
      end

      def apply_multi(file_blocks)
        @formatter.newline
        @formatter.info("This refactor produces #{file_blocks.length} file(s):")
        file_blocks.each do |block|
          path = block[:path] || @original_file
          label = block[:tag] == "new" ? "NEW" : "MODIFIED"
          @formatter.info("  [#{label}] #{path}")
        end

        print "\nApply all changes? (y/n/select) "
        choice = $stdin.gets&.strip&.downcase

        case choice
        when "y"
          file_blocks.each { |block| write_block(block) }
        when "select"
          file_blocks.each { |block| apply_selected(block) }
        else
          @formatter.info("All changes discarded.")
        end
      end

      def apply_selected(block)
        path = block[:path] || @original_file
        label = block[:tag] == "new" ? "NEW" : "MODIFIED"
        print "  Apply [#{label}] #{path}? (y/n/diff) "
        choice = $stdin.gets&.strip&.downcase

        case choice
        when "y"
          write_block(block)
        when "diff"
          existing = block[:tag] == "new" ? "" : File.read(resolve_path(block))
          Rubyn::Output::DiffRenderer.render(original: existing, modified: block[:code])
          print "  Apply? (y/n) "
          write_block(block) if $stdin.gets&.strip&.downcase == "y"
        else
          @formatter.info("  Skipped #{path}")
        end
      end

      def write_block(block)
        target = resolve_path(block)
        write_file(target, block[:code])
      end

      def write_file(path, code)
        dir = File.dirname(path)
        FileUtils.mkdir_p(dir) unless File.directory?(dir)
        created = !File.exist?(path)
        File.write(path, code)
        label = created ? "Created" : "Updated"
        @formatter.success("#{label} #{path}")
      end

      def resolve_path(block)
        return @original_file unless block[:path]

        if block[:path].start_with?("/")
          block[:path]
        else
          File.join(Dir.pwd, block[:path])
        end
      end
    end
  end
end
