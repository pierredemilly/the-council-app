module Api
  module Admin
    class SessionsController < BaseController
      PAGE_SIZE = 50

      def index
        sessions = ConversationSession.order(started_at: :desc).limit(PAGE_SIZE).includes(:events)
        render json: { sessions: AdminSessionSerializer.new(sessions).serializable_hash }
      end

      def show
        session = ConversationSession.find(params[:id])
        render json: {
          session: AdminSessionSerializer.new(session).serializable_hash,
          events: ConversationEventSerializer.new(session.events.ordered).serializable_hash.map.with_index do |event, index|
            event.merge("latency" => session.events.ordered[index].latency)
          end,
          errors: session.provider_errors.order(:created_at).map { |e| e.slice(:stage, :provider, :attempt, :recoverable, :message, :created_at) }
        }
      end

      def destroy
        ConversationSession.find(params[:id]).destroy!
        head :no_content
      end
    end
  end
end
