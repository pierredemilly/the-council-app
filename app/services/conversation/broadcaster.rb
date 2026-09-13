module Conversation
  # The only place that talks to Action Cable from the application side.
  module Broadcaster
    def self.broadcast(session, type, payload = {})
      ActionCable.server.broadcast(Protocol.stream_name(session.id), Protocol.envelope(session, type, payload))
    end
  end
end
