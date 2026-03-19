# frozen_string_literal: true

require "tty-spinner"

module Rubyn
  module Output
    class Spinner
      def initialize
        @spinner = nil
      end

      def start(message)
        @spinner = TTY::Spinner.new("[:spinner] #{message}", format: :dots)
        @spinner.auto_spin
      end

      def stop_success(message = "Done!")
        @spinner&.success(message)
      end

      def stop_error(message = "Failed!")
        @spinner&.error(message)
      end
    end
  end
end
