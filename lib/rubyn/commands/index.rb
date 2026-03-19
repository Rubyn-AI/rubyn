# frozen_string_literal: true

require "pastel"

module Rubyn
  module Commands
    class Index < Base
      PROGRESS_BAR_WIDTH = 30
      SUMMARY_BOX_WIDTH = 44

      def execute(force: false)
        formatter = Rubyn::Output::Formatter
        pastel = Pastel.new
        ensure_configured!

        formatter.header("Codebase Analysis")
        formatter.newline

        indexer = Rubyn::Context::CodebaseIndexer.new
        chunk_bar = nil
        upload_bar = nil

        result = indexer.index(force: force) do |progress|
          case progress[:phase]
          when :scan
            formatter.info(progress[:message])
            formatter.newline
          when :chunk
            if chunk_bar.nil?
              chunk_bar = TTY::Spinner::Multi.new("[:spinner] Chunking files")
              @file_spinners = {}
            end
            render_file_progress(chunk_bar, progress, pastel)
          when :upload
            chunk_bar&.success
            formatter.newline
            formatter.info(progress[:message])
          when :upload_batch
            if upload_bar.nil?
              upload_bar = TTY::Spinner.new(
                "[:spinner] Uploading batch :current/:total",
                format: :dots
              )
              upload_bar.auto_spin
            end
            upload_bar.update(current: progress[:current], total: progress[:total])
          when :complete
            upload_bar&.success("Done!")
            formatter.newline
            formatter.success(progress[:message])
          end
        end

        formatter.newline
        render_summary(formatter, pastel, result)
      rescue Rubyn::Error => e
        formatter.error(e.message)
      end

      private

      def render_file_progress(_multi, progress, pastel)
        pct = ((progress[:current].to_f / progress[:total]) * 100).round
        filled = (PROGRESS_BAR_WIDTH * progress[:current].to_f / progress[:total]).round
        empty = PROGRESS_BAR_WIDTH - filled

        bar = pastel.green("#" * filled) + pastel.dim("." * empty)
        file_name = truncate_path(progress[:file], 40)

        print "\r  #{bar} #{pct}%  #{pastel.dim(file_name)}#{" " * 20}"
        puts if progress[:current] == progress[:total]
      end

      def render_summary(_formatter, pastel, result)
        return if result.nil?

        border = pastel.dim("+#{"-" * (SUMMARY_BOX_WIDTH - 2)}+")
        spacer = pastel.dim("|") + (" " * (SUMMARY_BOX_WIDTH - 2)) + pastel.dim("|")

        puts border
        puts spacer
        puts row(pastel, "  Files analysed", result[:indexed].to_s, SUMMARY_BOX_WIDTH)
        puts row(pastel, "  Files skipped", result[:skipped].to_s, SUMMARY_BOX_WIDTH)
        puts row(pastel, "  Chunks created", result[:chunks].to_s, SUMMARY_BOX_WIDTH)
        puts spacer
        puts border
      end

      def row(pastel, label, value, width)
        content = "#{label}#{" " * (width - 4 - label.length - value.length)}#{pastel.bold(value)}"
        "#{pastel.dim("|")} #{content} #{pastel.dim("|")}"
      end

      def truncate_path(path, max)
        return path if path.length <= max

        "...#{path[-(max - 3)..]}"
      end
    end
  end
end
