# frozen_string_literal: true

module Rubyn
  module Commands
    class Dashboard
      DEFAULT_PORT = 9292

      def execute
        formatter = Rubyn::Output::Formatter

        if rails_project_with_engine?
          formatter.info("Dashboard available at: http://localhost:3000/rubyn")
          formatter.info("Start your Rails server with `rails s` to access.")
        else
          start_standalone_dashboard(formatter)
        end
      end

      private

      def rails_project_with_engine?
        routes_file = File.join(Dir.pwd, "config", "routes.rb")
        return false unless File.exist?(routes_file)

        File.read(routes_file).include?("Rubyn::Engine")
      end

      def start_standalone_dashboard(formatter)
        formatter.info("Starting standalone dashboard...")
        formatter.info("Dashboard: http://localhost:#{DEFAULT_PORT}/rubyn")

        require "sinatra/base"

        port = DEFAULT_PORT
        app = Class.new(Sinatra::Base) do
          set :port, port
          set :bind, "0.0.0.0"

          get "/rubyn" do
            content_type :html
            build_dashboard_html
          end

          get "/rubyn/health" do
            content_type :json
            { status: "ok", version: Rubyn::VERSION }.to_json
          end

          helpers do
            def build_dashboard_html
              <<~HTML
                <!DOCTYPE html>
                <html>
                <head>
                  <title>Rubyn Dashboard</title>
                  <style>
                    body { font-family: system-ui; background: #1a1a2e; color: #e0e0e0; margin: 0; padding: 2rem; }
                    h1 { color: #e94560; }
                    .card { background: #16213e; border-radius: 8px; padding: 1.5rem; margin: 1rem 0; }
                    .info { color: #a0a0a0; }
                  </style>
                </head>
                <body>
                  <h1>Rubyn Dashboard</h1>
                  <div class="card">
                    <h2>Standalone Mode</h2>
                    <p class="info">Mount the Rubyn engine in your Rails app for the full dashboard experience.</p>
                    <p class="info">Run: <code>rails generate rubyn:install</code></p>
                  </div>
                  <div class="card">
                    <h2>Version</h2>
                    <p>#{Rubyn::VERSION}</p>
                  </div>
                </body>
                </html>
              HTML
            end
          end
        end

        app.run!
      end
    end
  end
end
