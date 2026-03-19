# frozen_string_literal: true

require "pastel"
require "rouge"

module Rubyn
  module Output
    class Formatter
      class << self
        def header(text)
          puts "\n#{pastel.bold(text)}"
          puts pastel.dim("\u2500" * text.length)
        end

        def success(text)
          puts pastel.green("\u2713 #{text}")
        end

        def warning(text)
          puts pastel.yellow("\u26A0 #{text}")
        end

        def error(text)
          puts pastel.red("\u2717 #{text}")
        end

        def info(text)
          puts pastel.cyan("\u2192 #{text}")
        end

        def code_block(code, language: "ruby")
          puts highlight(code, language)
        end

        def credit_usage(credits, balance = nil)
          if balance
            puts pastel.dim("Credits: #{credits} used | #{balance} remaining")
          else
            puts pastel.dim("Credits: #{credits} used")
          end
        end

        def stream_print(text)
          print text
        end

        # Print response with syntax-highlighted code blocks
        def print_content(text)
          print_with_highlighted_code(text)
        end

        def newline
          puts
        end

        private

        def pastel
          @pastel ||= Pastel.new
        end

        def rouge_formatter
          @rouge_formatter ||= Rouge::Formatters::Terminal256.new(
            theme: Rouge::Themes::Monokai.new
          )
        end

        def highlight(code, language = "ruby")
          lexer = Rouge::Lexer.find(language) || Rouge::Lexers::Ruby.new
          rouge_formatter.format(lexer.lex(code))
        rescue Rouge::Error, ArgumentError
          code
        end

        # Parse markdown-style code blocks and highlight them,
        # pass everything else through as plain text
        def print_with_highlighted_code(text)
          in_code_block = false
          language = "ruby"
          code_buffer = []

          text.each_line do |line|
            if line.match?(/^```(\w*)/)
              if in_code_block
                # End of code block — highlight and print
                puts highlight(code_buffer.join, language)
                puts pastel.dim("```")
                code_buffer = []
                in_code_block = false
              else
                # Start of code block
                language = line.match(/^```(\w+)/)&.send(:[], 1) || "ruby"
                puts pastel.dim(line.chomp)
                in_code_block = true
              end
            elsif in_code_block
              code_buffer << line
            else
              # Regular text — print with light formatting
              print_formatted_line(line)
            end
          end

          # Flush any unclosed code block
          puts code_buffer.join if code_buffer.any?
        end

        def print_formatted_line(line)
          case line
          when /^\#{1,3}\s/
            puts pastel.bold(line.chomp)
          when /^\*\*(.+)\*\*/
            puts pastel.bold(line.gsub(/\*\*(.+?)\*\*/, '\1').chomp)
          when /^[-*]\s/
            puts pastel.cyan("  #{line.chomp}")
          else
            puts line.chomp
          end
        end
      end
    end
  end
end
