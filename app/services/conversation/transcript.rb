module Conversation
  # Decides which words were actually heard when playback stops early.
  module Transcript
    # timings: [{ "word" => "Hello", "start_ms" => 0, "end_ms" => 320 }, ...] or nil.
    def self.spoken_prefix(text:, position_ms:, timings: nil, duration_ms: nil)
      return "" if position_ms.to_i <= 0
      return text if duration_ms && position_ms >= duration_ms

      words = text.to_s.split(/\s+/)
      return text if words.empty?

      kept = if timings.present?
        timings.take_while { |t| t["end_ms"].to_i <= position_ms }.size
      elsif duration_ms.to_i.positive?
        (words.size * position_ms.to_f / duration_ms * 0.9).floor
      else
        0
      end

      words.first([ kept, words.size ].min).join(" ")
    end
  end
end
