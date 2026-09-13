module Conversation
  # Turns a session snapshot and its transcript into the model's instructions and input.
  class PromptBuilder
    HUMAN_LABEL = "VISITOR".freeze

    def initialize(input)
      @input = input
    end

    def instructions
      [ @input.system_prompt.to_s.strip, structural_rules, character_sheets ].reject(&:blank?).join("\n\n")
    end

    def messages(feedback: nil)
      messages = [ { role: :user, content: transcript_block } ]
      messages << { role: :user, content: feedback_block(feedback) } if feedback.present?
      messages
    end

    private

    def names
      @names ||= @input.agents.map { |agent| agent["name"] || agent[:name] }
    end

    def labels
      names.map(&:upcase)
    end

    def structural_rules
      directions = @input.stage_directions.map { |d| "[#{d}]" }
      <<~RULES.strip
        ## Format
        You write the next stretch of dialogue for exactly these three characters: #{labels.join(", ")}. The human taking part is labelled #{HUMAN_LABEL} and is never written by you.
        Return JSON with two keys: "dialogue" and "next_action".
        "dialogue" is script text: one line per turn, each paragraph formatted as `NAME: words`, using the exact labels above and blank lines between turns. No narration, no stage business outside brackets, no markdown.
        "next_action" is "wait_for_user" when the last line asks the #{HUMAN_LABEL} something or clearly needs their answer, and "yield_to_user" when the characters pause naturally but could go on.

        ## Rules
        - At most #{@input.max_turns} turns in total and no character speaks more than twice.
        - Keep turns short and spoken; the whole passage must take well under a minute to say aloud.
        - No fixed speaking order. Characters react to each other and to the #{HUMAN_LABEL}; they may interrupt one another when it feels natural.
        - Introduce a new topic only as a natural continuation of what was just said.
        - Never write, paraphrase or presume the #{HUMAN_LABEL}'s words.
        - A line marked (interrupted by the visitor) was cut off mid-sentence: the speaker did not finish and the group heard the #{HUMAN_LABEL} instead. React to that.
        - Bracketed stage directions are allowed only from this list: #{directions.presence&.join(" ") || "none"}.
        - #{language_rule}
        - Each character's vocabulary, beliefs, habits and syntax come from their sheet below.
      RULES
    end

    def language_rule
      if @input.language.present?
        "Write every line in #{@input.language}."
      else
        "Write every line in the language the #{HUMAN_LABEL} used in their most recent line (default: #{@input.fallback_language})."
      end
    end

    def character_sheets
      @input.agents.map do |agent|
        name = agent["name"] || agent[:name]
        sheet = (agent["personality"] || agent[:personality]).to_s.strip
        "## #{name.upcase}\n#{sheet.presence || "(no sheet yet)"}"
      end.join("\n\n")
    end

    def transcript_block
      lines = @input.transcript.map do |event|
        label = event["kind"] == "human" ? HUMAN_LABEL : event["speaker"].to_s.upcase
        suffix = event["interrupted"] ? " (interrupted by the visitor)" : ""
        "#{label}: #{event["text"]}#{suffix}"
      end
      interruptions = @input.transcript.each_with_index.select { |event, _| event["interrupted"] }.map { |event, index| "line #{index + 1} (#{event["speaker"]})" }

      block = "## Transcript so far\n#{lines.join("\n\n")}"
      block += "\n\n## Interruptions\nThe visitor cut off: #{interruptions.join(", ")}." if interruptions.any?
      block + "\n\nContinue the conversation from here."
    end

    def feedback_block(feedback)
      "Your previous answer was rejected: #{feedback}\nReturn a corrected JSON envelope that follows every rule."
    end
  end
end
