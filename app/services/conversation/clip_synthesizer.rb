module Conversation
  # Synthesizes a segment's turns concurrently and marks each one ready as soon as its clip is stored.
  class ClipSynthesizer
    def initialize(session, turns, version, tts: nil)
      @session = session
      @turns = turns
      @version = version
      @tts = tts || Providers::Registry.tts(session.snapshot)
    end

    def call
      results = Executor.inline ? @turns.map { |turn| synthesize(turn) } : synthesize_concurrently
      { first_clip_ms: results.compact.min }
    end

    private

    # Test runs stay single-threaded so they share the transactional connection; production fans out.
    def synthesize_concurrently
      futures = @turns.map do |turn|
        Concurrent::Promises.future_on(Executor.tts_pool) { Rails.application.executor.wrap { synthesize(turn) } }
      end
      Concurrent::Promises.zip(*futures).value!
    rescue Concurrent::MultipleErrors => e
      raise e.errors.first
    end

    def synthesize(turn)
      voice = voice_for(turn.speaker)
      result = @session.snapshot.retry_policy.run { @tts.synthesize(text: turn.text, voice_id: voice, language: @session.language) }
      ready_at = Process.clock_gettime(Process::CLOCK_MONOTONIC, :millisecond)

      stored = SessionStore.with_lock(@session.id, expected_version: @version) do |locked|
        current = locked.turns.find_by(id: turn.id)
        next nil unless current&.status == "pending"

        AudioClip.create!(conversation_session: locked, session_turn: current, mime: result.mime, bytes: result.audio,
                          duration_ms: result.duration_ms, timings: result.timings)
        current.update!(status: "ready", duration_ms: result.duration_ms)
        current
      end
      return nil unless stored

      Broadcaster.broadcast(@session, "agent.turn.ready", SessionTurnSerializer.new(stored.reload).serializable_hash)
      ready_at
    end

    def voice_for(speaker)
      agent = @session.snapshot.agents.find { |a| a["name"] == speaker }
      agent && agent["voice_id"]
    end
  end
end
