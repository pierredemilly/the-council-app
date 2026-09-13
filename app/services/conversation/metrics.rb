module Conversation
  module Metrics
    def self.summarize(session)
      events = session.events.ordered.to_a
      {
        "duration_s" => ((session.finalized_at || Time.current) - session.started_at).round,
        "human_turns" => events.count(&:human?),
        "agent_turns" => events.count(&:agent?),
        "interruptions" => events.count { |e| e.agent? && e.interrupted? }
      }
    end
  end
end
