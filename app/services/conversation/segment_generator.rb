module Conversation
  # Provider call → envelope → validated script, feeding validation errors back to the model.
  class SegmentGenerator
    Result = Data.define(:segment, :attempts, :latency_ms, :usage)

    def initialize(session, llm: nil, tts: nil)
      @session = session
      @snapshot = session.snapshot
      @llm = llm || Providers::Registry.llm(@snapshot)
      @tts = tts || Providers::Registry.tts(@snapshot)
    end

    def call
      input = build_input
      feedback = nil
      attempts = 0
      usage = Hash.new(0)
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC, :millisecond)

      loop do
        attempts += 1
        envelope = @snapshot.retry_policy.run { @llm.complete(input, feedback: feedback) }
        accumulate(usage, envelope.usage)
        begin
          segment = ScriptParser.parse(envelope, agent_names: @snapshot.agent_names, max_turns: @snapshot.max_ai_turns, stage_directions: input.stage_directions)
          latency_ms = Process.clock_gettime(Process::CLOCK_MONOTONIC, :millisecond) - started
          return Result.new(segment: segment, attempts: attempts, latency_ms: latency_ms, usage: usage)
        rescue ScriptParser::Invalid => e
          Rails.logger.info("[conversation] rejected script for #{@session.id} (attempt #{attempts}): #{e.message}")
          raise Providers::Error.new("The model kept producing an invalid script: #{e.message}", recoverable: true) if attempts > @snapshot.retry_count

          feedback = e.message
        end
      end
    end

    private

    def build_input
      Providers::Llm::Input.new(
        system_prompt: @snapshot.global_system_prompt,
        agents: @snapshot.agents,
        transcript: @session.events.ordered.spoken.map { |e| e.attributes.slice("kind", "speaker", "text", "interrupted") },
        max_turns: @snapshot.max_ai_turns,
        language: @session.language,
        fallback_language: @snapshot.fallback_language,
        stage_directions: @tts.stage_directions
      )
    end

    def accumulate(total, usage)
      usage.to_h.each { |key, value| total[key.to_s] += value if value.is_a?(Numeric) }
    end
  end
end
