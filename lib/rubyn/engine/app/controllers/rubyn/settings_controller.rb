# frozen_string_literal: true

module Rubyn
  class SettingsController < ApplicationController
    def show
      @settings = Config::Settings.all
      @credentials_exist = Config::Credentials.exists?
    end

    def update
      params.permit(:default_model, :auto_apply, :output_format).each do |key, value|
        Config::Settings.set(key, value)
      end
      redirect_to rubyn.settings_path, notice: "Settings updated."
    end
  end
end
