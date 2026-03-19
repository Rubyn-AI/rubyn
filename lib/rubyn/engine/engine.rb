# frozen_string_literal: true

module Rubyn
  class Engine < ::Rails::Engine
    isolate_namespace Rubyn

    # Engine files live under lib/rubyn/engine/ instead of the gem root
    engine_root = File.expand_path("..", __FILE__)

    config.root = engine_root

    initializer "rubyn.assets" do |app|
      if Rails.env.development? && app.config.respond_to?(:assets)
        app.config.assets.precompile += %w[rubyn/application.css rubyn/application.js rubyn/RubynLogo.png]
      end
    end
  end
end
