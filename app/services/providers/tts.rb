# Value objects shared by every TTS adapter.
module Providers
  module Tts
    # timings: [{ "word" => "Hello", "start_ms" => 0, "end_ms" => 320 }, ...] aligned with text.split(/\s+/), or nil.
    Result = Data.define(:audio, :mime, :duration_ms, :timings) do
      def initialize(audio:, mime:, duration_ms: nil, timings: nil)
        super
      end
    end

    # Groups per-character alignment into whitespace-delimited word timings matching Transcript's word split.
    def self.word_timings(text, characters, start_seconds, end_seconds)
      return nil if characters.blank? || characters.size != start_seconds.size

      words = []
      current = nil
      characters.each_with_index do |char, index|
        if char.match?(/\s/)
          words << current if current
          current = nil
          next
        end
        current ||= { "word" => "", "start_ms" => (start_seconds[index] * 1000).round }
        current["word"] << char
        current["end_ms"] = (end_seconds[index] * 1000).round
      end
      words << current if current
      words.size == text.split(/\s+/).size ? words : nil
    end
  end
end
