class AggregateSessionMetricsJob < ApplicationJob
  queue_as :default

  def perform(session_id)
    session = ConversationSession.find_by(id: session_id)
    return unless session&.finalized?

    session.update!(metrics: session.metrics.merge(Conversation::Metrics.summarize(session)))
  end
end
