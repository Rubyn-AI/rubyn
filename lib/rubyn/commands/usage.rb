# frozen_string_literal: true

module Rubyn
  module Commands
    class Usage < Base
      MAX_HISTORY_ENTRIES = 10

      def execute
        formatter = Rubyn::Output::Formatter
        ensure_credentials!

        formatter.header("Rubyn Usage")

        spinner = Rubyn::Output::Spinner.new
        spinner.start("Fetching usage data...")

        balance = Rubyn.api_client.get_balance
        history = Rubyn.api_client.get_history

        spinner.stop_success("Done!")

        display_balance(formatter, balance)
        display_history(formatter, history)
      rescue Rubyn::ConfigurationError
        raise
      rescue Rubyn::Error => e
        spinner&.stop_error("Failed")
        formatter.error(e.message)
      end

      private

      def display_balance(formatter, balance)
        formatter.newline
        formatter.info("Credits: #{balance["credit_balance"]}")
        formatter.info("Credit allowance: #{balance["credit_allowance"]}") if balance["credit_allowance"]
        formatter.info("Reset period: #{balance["reset_period"]}") if balance["reset_period"]
        formatter.info("Resets at: #{balance["resets_at"]}") if balance["resets_at"]
        formatter.newline
      end

      def display_history(formatter, history)
        entries = history["interactions"] || []
        return formatter.info("No recent activity.") if entries.empty?

        formatter.header("Recent Activity")
        entries.first(MAX_HISTORY_ENTRIES).each do |entry|
          time = entry["created_at"]
          command = entry["command"]
          credits = entry["credits_charged"]
          formatter.info("#{time}  #{command.ljust(10)}  #{credits} credits")
        end
      end
    end
  end
end
