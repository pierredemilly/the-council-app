module Conversation
  module Protocol
    VERSION = 1
    PAYLOAD_BYTE_LIMIT = 2.kilobytes
    UUID = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i
    MAX_MS = 6.hours.in_milliseconds

    CLIENT_TYPES = {
      "speech.started" => { turnId: :uuid, positionMs: :ms, durationMs: :ms },
      "speech.ended" => {},
      "playback.started" => { turnId: :uuid! },
      "playback.progress" => { turnId: :uuid!, positionMs: :ms! },
      "playback.stopped" => { turnId: :uuid!, positionMs: :ms!, durationMs: :ms },
      "playback.completed" => { turnId: :uuid!, spokenMs: :ms },
      "turn.request" => {},
      "session.idle_reset" => {},
      "client.heartbeat" => {}
    }.freeze

    SERVER_TYPES = %w[
      session.ready state.changed transcript.committed agent.turn.ready agent.segment.cancel
      error.recoverable error.fatal server.heartbeat
    ].freeze

    class InvalidMessage < Conversation::Error; end

    def self.stream_name(session_id)
      "conversation:#{session_id}"
    end

    def self.envelope(session, type, payload = {})
      raise ArgumentError, "unknown server message #{type}" unless SERVER_TYPES.include?(type)

      {
        protocolVersion: VERSION,
        type: type,
        sessionId: session.id,
        eventId: SecureRandom.uuid,
        version: session.version,
        seq: session.last_seq,
        sentAt: Time.current.iso8601(3),
        payload: payload
      }
    end

    # Returns [type, payload] with only the whitelisted, validated keys.
    def self.parse_client!(data)
      data = data.to_h.stringify_keys
      raise InvalidMessage, "message too large" if data.to_json.bytesize > PAYLOAD_BYTE_LIMIT
      raise InvalidMessage, "unsupported protocol version" if data["protocolVersion"].present? && data["protocolVersion"].to_i != VERSION

      type = data["type"].to_s
      schema = CLIENT_TYPES[type] or raise InvalidMessage, "unknown message type #{type.inspect}"
      raw = (data["payload"] || {}).to_h.stringify_keys

      payload = schema.each_with_object({}) do |(key, rule), acc|
        value = raw[key.to_s]
        required = rule.to_s.end_with?("!")
        raise InvalidMessage, "#{key} is required" if required && value.nil?
        next if value.nil?

        acc[key] = coerce!(key, value, rule.to_s.delete_suffix("!"))
      end

      [ type, payload ]
    end

    def self.coerce!(key, value, kind)
      case kind
      when "uuid"
        raise InvalidMessage, "#{key} must be a UUID" unless value.to_s.match?(UUID)
        value.to_s.downcase
      when "ms"
        ms = Integer(value, exception: false)
        raise InvalidMessage, "#{key} must be a duration in ms" if ms.nil? || ms.negative? || ms > MAX_MS
        ms
      end
    end
  end
end
