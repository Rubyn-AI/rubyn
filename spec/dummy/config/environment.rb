# frozen_string_literal: true

# Set Rails root to the dummy app BEFORE anything loads
ENV["RAILS_ENV"] = "test"

require_relative "application"
Dummy::Application.initialize!
