# frozen_string_literal: true

module Rubyn
  module Context
    class ResponseParser
      BOLD_HEADER = /\*\*(?:New|Updated|Modified)\s*(?:file)?:\s*([a-zA-Z0-9_\/\.\-]+\.rb)\*\*/i
      BACKTICK_PATH = /`([a-zA-Z0-9_\/\.\-]+\.rb)`\s*\z/
      INLINE_COMMENT = /^#\s*([a-zA-Z0-9_\/\.\-]+\.rb)/

      def self.extract_file_blocks(response)
        new(response).extract
      end

      def initialize(response)
        @response = response
      end

      def extract
        blocks = []
        parts = @response.split(/(```ruby\n.*?```)/m)

        parts.each_with_index do |part, i|
          next unless part.start_with?("```ruby\n")

          code = part.sub(/\A```ruby\n/, "").sub(/```\z/, "")
          preceding = i > 0 ? parts[i - 1] : ""
          path = detect_path(preceding, code)

          blocks << { path: path, code: code }
        end

        blocks
      end

      private

      def detect_path(preceding_text, code)
        match_bold_header(preceding_text) ||
          match_backtick_path(preceding_text) ||
          match_inline_comment(code)
      end

      def match_bold_header(text)
        text.match(BOLD_HEADER)&.[](1)
      end

      def match_backtick_path(text)
        text.match(BACKTICK_PATH)&.[](1)
      end

      def match_inline_comment(code)
        code.lines.first&.strip&.match(INLINE_COMMENT)&.[](1)
      end
    end
  end
end
