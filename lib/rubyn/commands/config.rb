# frozen_string_literal: true

module Rubyn
  module Commands
    class Config
      VALID_KEYS = %w[default_model auto_apply output_format].freeze

      def execute(key = nil, value = nil)
        formatter = Output::Formatter

        if key.nil?
          display_all(formatter)
        elsif value.nil?
          display_key(formatter, key)
        else
          set_key(formatter, key, value)
        end
      end

      private

      def display_all(formatter)
        formatter.header("Rubyn Configuration")
        Rubyn::Config::Settings.all.each do |k, v|
          formatter.info("#{k}: #{v}")
        end
      end

      def display_key(formatter, key)
        value = Rubyn::Config::Settings.get(key)
        if value.nil?
          formatter.warning("Unknown key: #{key}")
          formatter.info("Valid keys: #{VALID_KEYS.join(", ")}")
        else
          formatter.info("#{key}: #{value}")
        end
      end

      def set_key(formatter, key, value)
        unless VALID_KEYS.include?(key)
          formatter.error("Invalid key: #{key}")
          formatter.info("Valid keys: #{VALID_KEYS.join(", ")}")
          return
        end

        Rubyn::Config::Settings.set(key, value)
        formatter.success("#{key} set to #{value}")
      end
    end
  end
end
