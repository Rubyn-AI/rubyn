# frozen_string_literal: true

module Rubyn
  class AgentController < ApplicationController
    def show
      @conversations = begin
        api_client.list_conversations(project_token: project_token)
      rescue Rubyn::Error
        []
      end
    end

    def create
      result = api_client.agent_message(
        conversation_id: params[:conversation_id]&.to_i,
        message: params[:message],
        file_context: [],
        project_token: project_token
      )

      render json: result
    rescue Rubyn::Error => e
      render json: { error: e.message }, status: :unprocessable_entity
    end
  end
end
