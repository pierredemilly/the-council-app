module Conversation
  # One speculative generation attempt, pinned to the session version it started from.
  class SegmentRunner
    LATENCY_SAMPLES = 200

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

      stamp_generation_start(session)
      result = SegmentGenerator.new(session).call

      turns = SessionStore.with_lock(@session_id, expected_version: @version) do |locked|
        record_generation(locked, result)
        persist_turns(locked, result.segment)
      end
      timing = ClipSynthesizer.new(session, turns, @version).call
      record_first_clip(session, timing[:first_clip_ms])
    rescue StaleVersion
      Rails.logger.info("[conversation] discarded stale generation for #{@session_id}@#{@version}")
    rescue Providers::Error => e
      fail_generation(e.message, recoverable: e.recoverable)
    rescue StandardError => e
      Rails.logger.error("[conversation] generation crashed for #{@session_id}: #{e.class}: #{e.message}")
      fail_generation("Dialogue generation failed", recoverable: true)
    end

    private

    def stamp_generation_start(session)
      trigger = session.events.where(kind: "human").order(:seq).last
      trigger&.update!(latency: trigger.latency.merge("generation_started_ms" => Process.clock_gettime(Process::CLOCK_MONOTONIC, :millisecond)))
    end

    def persist_turns(session, segment)
      generation_id = SecureRandom.uuid
      session.turns.pending_playback.update_all(status: "discarded")
      segment.turns.each_with_index.map do |turn, index|
        session.turns.create!(
          generation_id: generation_id, version: @version, position: index,
          speaker: turn.speaker, text: turn.text, status: "pending",
          next_action: (index == segment.turns.size - 1 ? segment.next_action : nil)
        )
      end
    end

    def record_generation(session, result)
      metrics = session.metrics
      samples = (Array(metrics["llm_latency_ms"]) << result.latency_ms).last(LATENCY_SAMPLES)
      session.update!(metrics: metrics.merge(
        "llm_calls" => metrics.fetch("llm_calls", 0) + result.attempts,
        "llm_rejected_scripts" => metrics.fetch("llm_rejected_scripts", 0) + (result.attempts - 1),
        "llm_input_tokens" => metrics.fetch("llm_input_tokens", 0) + result.usage.fetch("input_tokens", 0),
        "llm_output_tokens" => metrics.fetch("llm_output_tokens", 0) + result.usage.fetch("output_tokens", 0),
        "llm_latency_ms" => samples
      ))
      trigger = session.events.where(kind: "human").order(:seq).last
      trigger&.update!(latency: trigger.latency.merge("llm_ms" => result.latency_ms))
    end

    def record_first_clip(session, ready_at_ms)
      trigger = session.events.where(kind: "human").order(:seq).last
      return unless trigger && ready_at_ms

      started = trigger.latency["generation_started_ms"]
      trigger.update!(latency: trigger.latency.merge("first_clip_ms" => started ? ready_at_ms - started : nil).compact)
    end

    def fail_generation(message, recoverable:)
      session = SessionStore.with_lock(@session_id, expected_version: @version) do |locked|
        locked.turns.pending_playback.update_all(status: "discarded")
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
