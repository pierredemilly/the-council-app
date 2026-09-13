module Providers
  module Llm
    # Deterministic dialogue for development and tests: echoes the visitor and ends on a question.
    class Fake < Base
      def complete(input, feedback: nil)
        names = input.agents.map { |agent| agent["name"] || agent[:name] }
        last_human = input.transcript.reverse.find { |event| event["kind"] == "human" }
        quote = last_human ? last_human["text"].to_s.truncate(80) : "nothing yet"
        last_agent = input.transcript.reverse.find { |event| event["kind"] == "agent" }
        interrupted = last_agent.present? && last_agent["interrupted"]

        lines = [
          "#{names[0].upcase}: #{interrupted ? 'Fair enough, you cut me off. Go on.' : "You said “#{quote}”. I have thoughts about that."}",
          "#{names[1].upcase}: Of course you do. I see it differently, and I suspect our guest does too.",
          "#{names[2].upcase}: [laughs] Let them speak. What made you think of that?"
        ]

        Envelope.new(dialogue: lines.first(input.max_turns).join("\n\n"), next_action: "wait_for_user", usage: { "fake" => true, "feedback" => feedback }, latency_ms: 0)
      end
    end
  end
end
