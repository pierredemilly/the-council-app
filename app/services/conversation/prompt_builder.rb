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
        "next_action" is "wait_for_user" when the last line asks the #{HUMAN_LABEL} something or clearly needs their answer; "yield_to_user" when the characters pause naturally but could go on; "continue" when the last line is addressed to another character (a question, a challenge, an invitation to react) so the group carries on without waiting for the #{HUMAN_LABEL}.

        ## Rules
        - At most #{@input.max_turns} turns in total and no character speaks more than twice. Not everyone has to speak: a passage with one or two lines is often the most natural answer, and a character who has nothing to add stays quiet.
        - Keep turns short and spoken; the whole passage must take well under a minute to say aloud.
        - This is a four-way conversation, not an interview. The #{HUMAN_LABEL} is one participant among four: in most passages at least one line answers, contradicts or teases another character rather than the #{HUMAN_LABEL}, and the characters pursue their own disagreements.
        - No fixed speaking order. Characters react to each other and to the #{HUMAN_LABEL}; they may interrupt one another when it feels natural.
        - Do not turn every line back to the #{HUMAN_LABEL} with a question. Ask the #{HUMAN_LABEL} something only when their view is genuinely wanted, and never end a passage on a question to another character with "wait_for_user".
        - Introduce a new topic only as a natural continuation of what was just said.
        - Never write, paraphrase or presume the #{HUMAN_LABEL}'s words.
        - A line marked (interrupted by the visitor) was cut off mid-sentence: the speaker did not finish and the group heard the #{HUMAN_LABEL} instead. React to that.
        - Bracketed stage directions are allowed only from this list: #{directions.presence&.join(" ") || "none"}.
        - #{language_rule}
        - Each character's vocabulary, beliefs, habits and syntax come from their sheet below.

        ## Sounding human
        These lines are spoken aloud by real people at a table, so they must never read like generated text. Readers spot machine writing by these habits; avoid every one of them, in every language, with its local equivalents.
        - Punctuation: no em dashes or en dashes (use a comma, a full stop or "..."), no semicolons, no colons inside speech, no bullet points, no bold, no emoji, no quotation marks around a word to flag it.
        - No contrast constructions: "it's not X, it's Y", "not just X but Y", "no X, no Y, just Z", "rather than X, Y", "less X than Y". State the point directly.
        - No lists of three, no chains of short punchy fragments ("Fast. Simple. Done."), no rhythmic parallel clauses. Real speech is lopsided: one example, or four, a sentence that runs on, a half-finished thought.
        - No warm-ups or self-congratulation: "Here's the thing", "Let me be clear", "That's the part everyone misses", "Great question", "Absolutely", "Certainly", "I hear you", "That's a fair point", "I appreciate you saying that".
        - No therapy speak: characters do not name their feelings, validate each other, "sit with" anything or thank each other for sharing. They react, argue, deflect, joke or go quiet. Subtext beats explanation.
        - No inflated vocabulary: "delve", "tapestry", "testament", "landscape", "pivotal", "crucial", "nuanced", "profound", "resonate", "navigate", "journey", "unpack", "underscore", "vibrant", "in many ways", "at the end of the day".
        - No hedging when a character has an opinion ("perhaps", "one could argue", "it depends"), and no tidy summaries of what the others said ("so what you're both saying is...").
        - No line that ends by wrapping the exchange into a lesson, a moral or a neat aphorism. Let it end on a detail, a jab, a question to someone or simply stop.
        - Use contractions, plain words, interjections, repetitions and false starts as people do when they speak. Characters may be wrong, blunt, petty, distracted or bored. They may answer a different question than the one asked, or not answer at all.
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
