module Conversation
  # One speculative generation attempt, pinned to the session version it started from.
  class SegmentRunner
    def self.enqueue(session_id, version)
      Executor.post { new(session_id, version).run }
    end

    def initialize(session_id, version)
      @session_id = session_id
      @version = version
    end

    def run
      session = ConversationSession.find(@session_id)
      return unless session.version == @version && session.status == "processing"

      started = Process.clock_gettime(Process::CLOCK_MONOTONIC, :millisecond)
      segment = session.snapshot.retry_policy.run { llm(session).generate_segment(input_for(session)) }
      latency_ms = Process.clock_gettime(Process::CLOCK_MONOTONIC, :millisecond) - started

      turns = SessionStore.with_lock(@session_id, expected_version: @version) do |locked|
        persist_turns(locked, segment, latency_ms)
      end
      turns.each { |turn| Broadcaster.broadcast(session, "agent.turn.ready", SessionTurnSerializer.new(turn).serializable_hash) }
    rescue StaleVersion
      Rails.logger.info("[conversation] discarded stale generation for #{@session_id}@#{@version}")
    rescue Providers::Error => e
      fail_generation(e.message, recoverable: e.recoverable)
    rescue StandardError => e
      Rails.logger.error("[conversation] generation crashed for #{@session_id}: #{e.class}: #{e.message}")
      fail_generation("Dialogue generation failed", recoverable: true)
    end

    private

    def llm(session)
      Providers::Registry.llm(session.snapshot)
    end

    def input_for(session)
      snapshot = session.snapshot
      Providers::Llm::Input.new(
        system_prompt: snapshot.global_system_prompt,
        agents: snapshot.agents,
        transcript: session.events.ordered.spoken.map { |e| e.attributes.slice("kind", "speaker", "text", "interrupted") },
        max_turns: snapshot.max_ai_turns,
        language: session.language,
        fallback_language: snapshot.fallback_language
      )
    end

    def persist_turns(session, segment, latency_ms)
      generation_id = SecureRandom.uuid
      session.turns.pending_playback.update_all(status: "discarded")
      turns = segment.turns.each_with_index.map do |turn, index|
        session.turns.create!(
          generation_id: generation_id, version: @version, position: index,
          speaker: turn.speaker, text: turn.text, status: "ready",
          next_action: (index == segment.turns.size - 1 ? segment.next_action : nil)
        )
      end
      session.update!(metrics: session.metrics.merge("last_llm_ms" => latency_ms))
      turns
    end

    def fail_generation(message, recoverable:)
      session = SessionStore.with_lock(@session_id, expected_version: @version) do |locked|
        locked.update!(status: "errored")
        locked
      end
      Broadcaster.broadcast(session, "error.recoverable", { code: "generation_failed", message: message, retryable: recoverable })
      Broadcaster.broadcast(session, "state.changed", { status: "errored" })
    rescue StaleVersion
      nil
    end
  end
end
