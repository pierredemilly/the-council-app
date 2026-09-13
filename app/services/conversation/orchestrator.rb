module Conversation
  # State machine for one session. Every mutation happens under the session row lock.
  class Orchestrator
    TEXT_CHAR_LIMIT = 2_000

    attr_reader :session

    def initialize(session)
      @session = session
    end

    def dispatch(type, payload)
      case type
      when "speech.started" then interrupt!(turn_id: payload[:turnId], position_ms: payload[:positionMs], duration_ms: payload[:durationMs])
      when "speech.ended", "playback.progress" then touch_activity!
      when "playback.started" then playback_started!(payload[:turnId], duration_ms: payload[:durationMs])
      when "playback.stopped" then interrupt!(turn_id: payload[:turnId], position_ms: payload[:positionMs], duration_ms: payload[:durationMs])
      when "playback.completed" then playback_completed!(payload[:turnId], spoken_ms: payload[:spokenMs])
      when "turn.request" then request_turn!
      when "session.idle_reset" then finalize!("inactivity")
      when "client.heartbeat" then heartbeat!
      end
    end

    def ready_payload
      session.reload
      {
        status: session.status,
        clientMode: session.client_mode,
        language: session.language,
        config: session.snapshot.public_payload,
        events: ConversationEventSerializer.new(session.events.ordered).serializable_hash,
        pendingTurns: SessionTurnSerializer.new(session.turns.for_version(session.version).where(status: %w[ready playing]).ordered).serializable_hash,
        nextAction: last_next_action,
        resumeDeadline: session.resume_deadline.iso8601
      }
    end

    def start_from_utterance!(text:, latency: {})
      text = text.to_s.strip
      raise ArgumentError, "text is blank" if text.blank?
      raise ArgumentError, "text is too long" if text.length > TEXT_CHAR_LIMIT
      ensure_active!

      event = SessionStore.with_lock(session.id) do |locked|
        locked.turns.pending_playback.update_all(status: "discarded")
        locked.first_utterance_at ||= Time.current
        locked.status = "processing"
        SessionStore.advance_version!(locked)
        SessionStore.append_event!(locked, kind: "human", text: text, latency: latency)
      end
      session.reload
      broadcast("transcript.committed", event: serialize(event))
      broadcast("state.changed", status: "processing")
      SegmentRunner.enqueue(session.id, session.version)
      event
    end

    # Human speech during playback: keep what was heard, drop everything else, invalidate in-flight work.
    # The browser owns playback timing, so it may report the clip duration it used.
    def interrupt!(turn_id: nil, position_ms: nil, duration_ms: nil)
      ensure_active!
      committed = nil
      changed = false
      SessionStore.with_lock(session.id) do |locked|
        next unless %w[speaking processing].include?(locked.status)

        changed = true

        turn = turn_id && locked.turns.for_version(locked.version).find_by(id: turn_id)
        if turn && !turn.spoken?
          prefix = Transcript.spoken_prefix(text: turn.text, position_ms: position_ms.to_i, timings: turn.audio_clip&.timings,
                                            duration_ms: turn.duration_ms || duration_ms)
          if prefix.present?
            committed = SessionStore.append_event!(locked, kind: "agent", speaker: turn.speaker, text: prefix,
                                                   interrupted: prefix != turn.text, spoken_ms: position_ms)
          end
        end
        discard_pending!(locked)
        locked.status = "listening"
        SessionStore.advance_version!(locked)
      end
      session.reload
      # Always acknowledged: the browser holds back late turn announcements until it hears this.
      broadcast("agent.segment.cancel", {})
      return unless changed

      broadcast("transcript.committed", event: serialize(committed)) if committed
      broadcast("state.changed", status: "listening", nextAction: nil)
    end

    def playback_started!(turn_id, duration_ms: nil)
      ensure_active!
      SessionStore.with_lock(session.id) do |locked|
        turn = locked.turns.for_version(locked.version).find_by(id: turn_id)
        next unless turn&.status == "ready"

        turn.update!(status: "playing", duration_ms: turn.duration_ms || duration_ms)
        locked.update!(status: "speaking", last_activity_at: Time.current)
      end
      session.reload
      broadcast("state.changed", status: "speaking", speaker: current_speaker) if session.status == "speaking"
    end

    def playback_completed!(turn_id, spoken_ms: nil)
      ensure_active!
      event = nil
      finished_segment = false
      SessionStore.with_lock(session.id) do |locked|
        turn = locked.turns.for_version(locked.version).find_by(id: turn_id)
        next unless turn && %w[ready playing].include?(turn.status)

        event = SessionStore.append_event!(locked, kind: "agent", speaker: turn.speaker, text: turn.text, spoken_ms: spoken_ms || turn.duration_ms)
        turn.update!(status: "spoken")
        turn.audio_clip&.delete
        if turn.last_in_segment?
          finished_segment = true
          locked.update!(status: "listening")
        end
      end
      return unless event

      session.reload
      broadcast("transcript.committed", event: serialize(event))
      broadcast("state.changed", status: "listening", nextAction: last_next_action) if finished_segment
      event
    end

    # After a yield grace period, or when the visitor retries after an error.
    def request_turn!
      ensure_active!
      started = SessionStore.with_lock(session.id) do |locked|
        next false unless %w[listening errored].include?(locked.status) && locked.events.exists?(kind: "human")

        locked.turns.pending_playback.update_all(status: "discarded")
        locked.status = "processing"
        SessionStore.advance_version!(locked)
        true
      end
      return unless started

      session.reload
      broadcast("state.changed", status: "processing")
      SegmentRunner.enqueue(session.id, session.version)
    end

    def finalize!(reason)
      return if session.finalized?

      SessionStore.with_lock(session.id) do |locked|
        next if locked.finalized?

        locked.turns.pending_playback.update_all(status: "discarded")
        locked.audio_clips.delete_all
        locked.update!(status: "finalized", finalized_at: Time.current, finalize_reason: reason, metrics: locked.metrics.merge(Metrics.summarize(locked)))
        SessionStore.advance_version!(locked)
      end
      session.reload
      broadcast("state.changed", status: "finalized", reason: reason)
    end

    def heartbeat!
      session.update_columns(last_seen_at: Time.current)
    end

    def connected!
      session.update_columns(last_seen_at: Time.current)
    end

    def disconnected!
      session.update_columns(last_seen_at: Time.current)
    end

    def touch_activity!
      session.update_columns(last_activity_at: Time.current, last_seen_at: Time.current)
    end

    private

    def discard_pending!(locked)
      pending = locked.turns.pending_playback
      AudioClip.where(session_turn_id: pending.select(:id)).delete_all
      pending.update_all(status: "discarded")
    end

    def ensure_active!
      raise Inactive, "session #{session.id} is finalized" if session.reload.finalized?
    end

    def broadcast(type, payload)
      Broadcaster.broadcast(session, type, payload)
    end

    def serialize(event)
      ConversationEventSerializer.new(event).serializable_hash
    end

    def current_speaker
      session.turns.for_version(session.version).find_by(status: "playing")&.speaker
    end

    def last_next_action
      return nil unless session.status == "listening"

      session.turns.for_version(session.version).where(status: "spoken").ordered.last&.next_action ||
        session.turns.where(status: "spoken").order(:created_at, :position).last&.next_action
    end
  end
end
