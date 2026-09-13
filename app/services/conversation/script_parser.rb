module Conversation
  # Validates the model's envelope and turns it into canonical turns.
  class ScriptParser
    class Invalid < Conversation::Error; end

    NEXT_ACTIONS = %w[wait_for_user yield_to_user].freeze
    MAX_TURNS_PER_SPEAKER = 2
    LINE = /\A([^:\n]{1,60}):\s*(.+)\z/m
    DIRECTION = /\[([^\[\]]{1,40})\]/

    def self.parse(envelope, agent_names:, max_turns:, stage_directions: [])
      new(agent_names: agent_names, max_turns: max_turns, stage_directions: stage_directions).parse(envelope)
    end

    def initialize(agent_names:, max_turns:, stage_directions: [])
      @canonical = agent_names.index_by { |name| name.to_s.strip.downcase }
      @max_turns = max_turns
      @stage_directions = stage_directions.map(&:downcase)
    end

    def parse(envelope)
      next_action = envelope.next_action.to_s
      raise Invalid, "next_action must be one of #{NEXT_ACTIONS.join(', ')}" unless NEXT_ACTIONS.include?(next_action)

      turns = split_lines(envelope.dialogue).map { |line| parse_line(line) }
      raise Invalid, "the dialogue is empty" if turns.empty?
      raise Invalid, "#{turns.size} turns exceed the maximum of #{@max_turns}" if turns.size > @max_turns

      turns.group_by(&:speaker).each do |speaker, spoken|
        raise Invalid, "#{speaker} speaks #{spoken.size} times; the maximum is #{MAX_TURNS_PER_SPEAKER}" if spoken.size > MAX_TURNS_PER_SPEAKER
      end

      Providers::Llm::Segment.new(turns: turns, next_action: next_action, usage: envelope.usage, latency_ms: envelope.latency_ms)
    end

    private

    def split_lines(dialogue)
      dialogue.to_s.gsub("\r", "").split(/\n+/).map(&:strip).reject(&:blank?)
    end

    def parse_line(line)
      match = LINE.match(line) or raise Invalid, "malformed line, expected `NAME: text`: #{line.truncate(60)}"
      label, text = match[1].strip, match[2].strip
      speaker = @canonical[label.downcase]
      raise Invalid, "the visitor's lines must never be written (#{label})" if label.casecmp?(PromptBuilder::HUMAN_LABEL)
      raise Invalid, "unknown speaker #{label}" unless speaker
      raise Invalid, "#{speaker} has an empty line" if text.gsub(DIRECTION, "").strip.empty?

      text.scan(DIRECTION).flatten.each do |direction|
        raise Invalid, "unsupported stage direction [#{direction}]" unless @stage_directions.include?(direction.strip.downcase)
      end

      Providers::Llm::Turn.new(speaker: speaker, text: text)
    end
  end
end
