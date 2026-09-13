module Providers
  module Llm
    # Deterministic dialogue for development and tests: echoes the visitor and ends on a question.
    class Fake < Base
      def generate_segment(input)
        names = input.agents.map { |agent| agent["name"] || agent[:name] }
        last_human = input.transcript.reverse.find { |event| event["kind"] == "human" }
        quote = last_human ? last_human["text"].to_s.truncate(80) : "nothing yet"
        last_agent = input.transcript.reverse.find { |event| event["kind"] == "agent" }
        interrupted = last_agent.present? && last_agent["interrupted"]

        turns = [
          Turn.new(speaker: names[0], text: interrupted ? "Fair enough, you cut me off. Go on." : "You said “#{quote}”. I have thoughts about that."),
          Turn.new(speaker: names[1], text: "Of course you do. I see it differently, and I suspect our guest does too."),
          Turn.new(speaker: names[2], text: "Let them speak. What made you think of that?")
        ]

        Segment.new(turns: turns.first(input.max_turns), next_action: "wait_for_user", usage: { "fake" => true }, latency_ms: 0)
      end
    end
  end
end
