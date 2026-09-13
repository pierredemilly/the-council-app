module ConversationHelpers
  def create_conversation(client_mode: "browser", llm_provider: "fake")
    AppConfig.current.update!(llm_provider: llm_provider)
    Agent.find_or_create_by!(position: 1) { |a| a.name = "Aphra" }
    Agent.find_or_create_by!(position: 2) { |a| a.name = "Rosa" }
    Agent.find_or_create_by!(position: 3) { |a| a.name = "Claudia" }
    Conversation::SessionStore.create!(client_mode: client_mode)
  end

  def broadcasts_for(session)
    ActionCable.server.pubsub.broadcasts(Conversation::Protocol.stream_name(session.id)).map { |raw| JSON.parse(raw) }
  end

  def broadcast_types(session)
    broadcasts_for(session).map { |message| message["type"] }
  end
end

RSpec.configure do |config|
  config.include ConversationHelpers
end
