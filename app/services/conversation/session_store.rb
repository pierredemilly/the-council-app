module Conversation
  # PostgreSQL-backed session state: authorization, row locks, sequence numbers and versions.
  module SessionStore
    def self.create!(client_mode:)
      ConversationSession.build_from_live_config(client_mode: client_mode).tap(&:save!)
    end

    def self.find_authorized(id, token)
      return nil if id.blank? || !id.to_s.match?(Protocol::UUID)

      session = ConversationSession.find_by(id: id)
      session if session&.authenticate(token)
    end

    def self.find_authorized!(id, token)
      find_authorized(id, token) or raise NotAuthorized
    end

    # Yields the session locked FOR UPDATE inside a transaction; the block's value is returned.
    def self.with_lock(session_id, expected_version: nil)
      ConversationSession.transaction do
        session = ConversationSession.lock.find(session_id)
        if expected_version && session.version != expected_version
          raise StaleVersion, "session #{session_id} moved from #{expected_version} to #{session.version}"
        end

        yield session
      end
    end

    # Appends a canonical event with the next sequence number. Call inside with_lock.
    def self.append_event!(session, kind:, text:, speaker: nil, interrupted: false, spoken_ms: nil, latency: {})
      event = session.events.create!(
        seq: session.next_seq, kind: kind, speaker: speaker, text: text,
        interrupted: interrupted, spoken_ms: spoken_ms, latency: latency, occurred_at: Time.current
      )
      session.next_seq += 1
      session.last_activity_at = Time.current
      session.save!
      event
    end

    # The version is the generation epoch: it moves whenever in-flight speculative work must be discarded.
    def self.advance_version!(session)
      session.version += 1
      session.last_activity_at = Time.current
      session.save!
      session
    end
  end
end
