# frozen_string_literal: true

module Rubyn
  module Context
    class ResponseParser
      FILE_EXT = /[a-zA-Z0-9_\/\.\-]+\.[a-zA-Z0-9\.]+/
      BOLD_HEADER = /\*\*(New|Updated|Modified)\s*(?:file)?:\s*(#{FILE_EXT})\*\*/i
      BACKTICK_PATH = /`(#{FILE_EXT})`\s*\z/
      INLINE_COMMENT = /^(?:#|<%#)\s*(#{FILE_EXT})/
      CODE_FENCE = /```\w+\n.*?```/m

      def self.extract_file_blocks(response)
        new(response).extract
      end

      def initialize(response)
        @response = response
      end

      def extract
        blocks = []
        parts = @response.split(/(#{CODE_FENCE})/m)

        parts.each_with_index do |part, i|
          next unless part.match?(/\A```\w+\n/)

          code = part.sub(/\A```\w+\n/, "").sub(/```\z/, "")
          preceding = i > 0 ? parts[i - 1] : ""
          result = detect_path(preceding, code)

          blocks << { path: result[:path], tag: result[:tag], code: code }
        end

        blocks
      end

      private

      def detect_path(preceding_text, code)
        match_bold_header(preceding_text) ||
          match_backtick_path(preceding_text) ||
          match_inline_comment(code) ||
          { path: nil, tag: nil }
      end

      def match_bold_header(text)
        m = text.match(BOLD_HEADER)
        return nil unless m

        { path: m[2], tag: m[1].downcase }
      end

      def match_backtick_path(text)
        m = text.match(BACKTICK_PATH)
        return nil unless m

        { path: m[1], tag: nil }
      end

      def match_inline_comment(code)
        m = code.lines.first&.strip&.match(INLINE_COMMENT)
        return nil unless m

        { path: m[1], tag: nil }
      end
    end
  end
end
