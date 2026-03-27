# frozen_string_literal: true

require "faraday"
require "faraday/multipart"
require "json"

module Rubyn
  module Client
    class ApiClient
      attr_reader :base_url

      def initialize(base_url: nil, api_key: nil)
        @base_url = base_url || Rubyn.configuration.api_url
        @api_key = api_key
      end

      def verify_auth
        post("/api/v1/auth/verify")
      end

      def refactor(file_path:, code:, context_files:, project_token:)
        post("/api/v1/ai/refactor", {
               file_path: file_path,
               code: code,
               context_files: context_files,
               project_token: project_token
             })
      end

      def generate_spec(file_path:, code:, context_files:, project_token:)
        post("/api/v1/ai/spec", {
               file_path: file_path,
               code: code,
               context_files: context_files,
               project_token: project_token
             })
      end

      def review(files:, context_files:, project_token:)
        post("/api/v1/ai/review", {
               files: files,
               context_files: context_files,
               project_token: project_token
             })
      end

      def agent_message(conversation_id:, message:, file_context:, project_token:)
        post("/api/v1/ai/agent", {
               conversation_id: conversation_id,
               message: message,
               file_context: file_context,
               project_token: project_token
             })
      end

      def submit_tool_results(conversation_id:, tool_results:, project_token:)
        post("/api/v1/ai/agent/tool_results", {
               conversation_id: conversation_id,
               tool_results: tool_results,
               project_token: project_token
             })
      end

      def list_conversations(project_token:)
        get("/api/v1/conversations", project_token: project_token)
      end

      def get_conversation(id:, project_token:)
        get("/api/v1/conversations/#{id}", project_token: project_token)
      end

      def sync_project(metadata:, project_token:)
        post("/api/v1/projects/sync", {
               project_token: project_token,
               name: metadata[:project_name],
               project_type: metadata[:project_type],
               ruby_version: metadata[:ruby_version],
               rails_version: metadata[:rails_version],
               test_framework: metadata[:test_framework],
               factory_library: metadata[:factory_library],
               gems_snapshot: metadata[:gems],
               directory_structure: metadata[:directory_structure]
             })
      end

      def index_project(project_token:, files:)
        post("/api/v1/projects/index", project_token: project_token, files: files)
      end

      def join_project(project_token:)
        post("/api/v1/projects/join", project_token: project_token)
      end

      def get_balance
        get("/api/v1/usage/balance")
      end

      def get_history(page: 1)
        get("/api/v1/usage/history", page: page)
      end

      def submit_feedback(interaction_id:, rating:, feedback: nil)
        post("/api/v1/feedback", {
               interaction_id: interaction_id,
               rating: rating,
               feedback: feedback
             })
      end

      private

      def api_key
        @api_key || Rubyn::Config::Credentials.api_key
      end

      def connection
        @connection ||= Faraday.new(url: @base_url) do |f|
          f.request :json
          f.response :json, content_type: /\bjson$/
          f.adapter Faraday.default_adapter
          f.options.timeout = 300
          f.options.open_timeout = 10
          f.headers["Authorization"] = "Bearer #{api_key}" if api_key
          f.headers["User-Agent"] = "rubyn-gem/#{Rubyn::VERSION}"
        end
      end

      def get(path, params = {})
        response = connection.get(path, params)
        parse_response(response)
      rescue Faraday::ConnectionFailed, Faraday::TimeoutError => e
        raise APIError, "Could not connect to #{@base_url} — #{e.message}"
      end

      def post(path, body = {})
        response = connection.post(path, body)
        parse_response(response)
      rescue Faraday::ConnectionFailed, Faraday::TimeoutError => e
        raise APIError, "Could not connect to #{@base_url} — #{e.message}"
      end

      def parse_response(response)
        json_body = response.body.is_a?(Hash) || response.body.is_a?(Array)

        if response.status.between?(200, 299)
          raise APIError, "Unexpected response from server (status #{response.status}). Expected JSON but got #{response.headers["content-type"] || "unknown content type"}." unless json_body
          return response.body
        end

        message = json_body ? extract_error_message(response) : nil

        case response.status
        when 400
          raise APIError, message || "Bad request"
        when 401
          raise AuthenticationError, "Invalid API key. Run `rubyn init` to reconfigure."
        when 402
          raise APIError, message || "Insufficient credits. Check your balance with `rubyn usage`."
        when 403
          raise AuthenticationError, message || "Access denied. Check your project membership."
        when 404
          raise APIError, message || "Resource not found."
        when 422
          raise APIError, message || "Unprocessable entity"
        when 429
          raise APIError, "Rate limit exceeded. Please wait and try again."
        else
          raise APIError, "Unexpected error (#{response.status}): #{message}"
        end
      end

      def extract_error_message(response)
        body = response.body
        return body["error"] if body.is_a?(Hash) && body["error"]
        return body.to_s unless body.nil? || (body.is_a?(String) && body.empty?)

        nil
      end
    end
  end
end
