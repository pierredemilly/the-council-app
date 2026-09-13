# Value objects shared by every LLM adapter.
module Providers
  module Llm
    Input = Data.define(:system_prompt, :agents, :transcript, :max_turns, :language, :fallback_language, :stage_directions) do
      def initialize(system_prompt:, agents:, transcript:, max_turns: 6, language: nil, fallback_language: "en", stage_directions: [])
        super
      end
    end

    # Raw structured answer from the model, before script validation.
    Envelope = Data.define(:dialogue, :next_action, :usage, :latency_ms) do
      def initialize(dialogue:, next_action:, usage: {}, latency_ms: nil)
        super
      end
    end

    Turn = Data.define(:speaker, :text)

    Segment = Data.define(:turns, :next_action, :usage, :latency_ms) do
      def initialize(turns:, next_action:, usage: {}, latency_ms: nil)
        super
      end
    end
  end
end
