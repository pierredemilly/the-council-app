class AdminSessionSerializer
  include Alba::Resource

  attributes :id, :status, :client_mode, :language, :started_at, :first_utterance_at, :finalized_at, :finalize_reason, :metrics

  attribute :human_turns do |session|
    session.events.count(&:human?)
  end

  attribute :agent_turns do |session|
    session.events.count(&:agent?)
  end

  attribute :interruptions do |session|
    session.events.count { |e| e.agent? && e.interrupted? }
  end

  attribute :first_line do |session|
    session.events.find(&:human?)&.text&.truncate(80)
  end
end
