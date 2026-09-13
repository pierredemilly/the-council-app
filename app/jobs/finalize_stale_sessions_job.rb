class FinalizeStaleSessionsJob < ApplicationJob
  queue_as :default

  def perform
    ConversationSession.active.find_each do |session|
      Conversation::Orchestrator.new(session).finalize!("abandoned") if session.resume_deadline <= Time.current
    end
  end
end
