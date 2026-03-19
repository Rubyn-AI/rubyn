# frozen_string_literal: true

module Rubyn
  class InstallGenerator < Rails::Generators::Base
    desc "Install Rubyn engine"

    def add_route
      route 'mount Rubyn::Engine => "/rubyn" if Rails.env.development?'
    end

    def show_instructions
      say "Rubyn engine mounted at /rubyn (development only)"
      say "Run 'rubyn init' to configure your API key and project"
    end
  end
end
