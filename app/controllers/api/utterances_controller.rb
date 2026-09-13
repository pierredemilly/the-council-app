module Api
  class UtterancesController < BaseController
    rate_limit to: 60, within: 1.minute, with: -> { render json: { error: "Too many utterances" }, status: :too_many_requests }

    def create
      event = Conversation::Orchestrator.new(current_session).start_from_utterance!(text: params[:text])
      render json: { event: ConversationEventSerializer.new(event).serializable_hash }, status: :accepted
    end
  end
end
