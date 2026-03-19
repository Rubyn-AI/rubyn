# frozen_string_literal: true

module Rubyn
  class FeedbackController < ApplicationController
    def create
      result = api_client.submit_feedback(
        interaction_id: params[:interaction_id].to_i,
        rating: params[:rating],
        feedback: params[:feedback]
      )

      render json: result
    rescue Rubyn::Error => e
      render json: { error: e.message }, status: :unprocessable_entity
    end
  end
end
