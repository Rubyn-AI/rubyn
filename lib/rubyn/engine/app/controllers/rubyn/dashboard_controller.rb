# frozen_string_literal: true

module Rubyn
  class DashboardController < ApplicationController
    def index
      @balance = begin
        api_client.get_balance
      rescue Rubyn::Error
        {}
      end
      @history = begin
        api_client.get_history(page: 1)
      rescue Rubyn::Error
        {}
      end
      @project = project_config
    end
  end
end
