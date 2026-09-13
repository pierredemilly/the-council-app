module Api
  class BaseController < ApplicationController
    rescue_from ActiveRecord::RecordNotFound, Conversation::NotAuthorized do
      render json: { error: "Session not found" }, status: :not_found
    end

    rescue_from Conversation::Inactive do
      render json: { error: "Session is finished" }, status: :gone
    end

    rescue_from ArgumentError do |error|
      render json: { error: error.message }, status: :unprocessable_content
    end

    private

    def current_session
      @current_session ||= Conversation::SessionStore.find_authorized!(params[:session_id] || params[:id], session_token)
    end

    def session_token
      request.headers["X-Session-Token"].presence || params[:token]
    end
  end
end
