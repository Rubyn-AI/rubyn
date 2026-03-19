# frozen_string_literal: true

require "pastel"

module Rubyn
  module Output
    class DiffRenderer
      class << self
        def render(original:, modified:)
          original_lines = original.lines
          modified_lines = modified.lines

          pastel = Pastel.new
          output = []
          output << pastel.bold("--- original")
          output << pastel.bold("+++ modified")

          diff = compute_diff(original_lines, modified_lines)
          diff.each do |change|
            case change[:type]
            when :unchanged
              output << " #{change[:line]}"
            when :removed
              output << pastel.red("- #{change[:line]}")
            when :added
              output << pastel.green("+ #{change[:line]}")
            end
          end

          puts output.join
        end

        private

        def compute_diff(original, modified)
          changes = []
          orig_idx = 0
          mod_idx = 0

          lcs = compute_lcs(original, modified)
          lcs_idx = 0

          while orig_idx < original.size || mod_idx < modified.size
            if lcs_idx < lcs.size && orig_idx < original.size && original[orig_idx] == lcs[lcs_idx] &&
               mod_idx < modified.size && modified[mod_idx] == lcs[lcs_idx]
              changes << { type: :unchanged, line: original[orig_idx] }
              orig_idx += 1
              mod_idx += 1
              lcs_idx += 1
            elsif orig_idx < original.size && (lcs_idx >= lcs.size || original[orig_idx] != lcs[lcs_idx])
              changes << { type: :removed, line: original[orig_idx] }
              orig_idx += 1
            elsif mod_idx < modified.size
              changes << { type: :added, line: modified[mod_idx] }
              mod_idx += 1
            end
          end

          changes
        end

        def compute_lcs(a, b)
          dp = build_dp_table(a, b)
          backtrack_lcs(dp, a, b)
        end

        def build_dp_table(a, b)
          m = a.size
          n = b.size
          dp = Array.new(m + 1) { Array.new(n + 1, 0) }

          (1..m).each do |i|
            (1..n).each do |j|
              dp[i][j] = if a[i - 1] == b[j - 1]
                           dp[i - 1][j - 1] + 1
                         else
                           [dp[i - 1][j], dp[i][j - 1]].max
                         end
            end
          end

          dp
        end

        def backtrack_lcs(dp, a, b)
          lcs = []
          i = a.size
          j = b.size
          while i.positive? && j.positive?
            if a[i - 1] == b[j - 1]
              lcs.unshift(a[i - 1])
              i -= 1
              j -= 1
            elsif dp[i - 1][j] > dp[i][j - 1]
              i -= 1
            else
              j -= 1
            end
          end

          lcs
        end
      end
    end
  end
end
