# Value objects shared by every LLM adapter.
module Providers
  module Llm
    Input = Data.define(:system_prompt, :agents, :transcript, :max_turns, :language, :fallback_language) do
      def initialize(system_prompt:, agents:, transcript:, max_turns: 6, language: nil, fallback_language: "en")
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
