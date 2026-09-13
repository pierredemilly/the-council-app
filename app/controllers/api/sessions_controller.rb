module Api
  class SessionsController < BaseController
    rate_limit to: 20, within: 1.minute, only: :create, with: -> { render json: { error: "Too many sessions" }, status: :too_many_requests }

    def create
      client_mode = ConversationSession::CLIENT_MODES.include?(params[:clientMode]) ? params[:clientMode] : "browser"
      conversation = Conversation::SessionStore.create!(client_mode: client_mode)
      render json: { session: ConversationSessionSerializer.new(conversation).serializable_hash.merge(token: conversation.client_token) }, status: :created
    end

    def show
      render json: { session: ConversationSessionSerializer.new(current_session).serializable_hash }
    end
  end
end
