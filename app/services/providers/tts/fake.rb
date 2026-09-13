module Providers
  module Tts
    # Silent WAV clips with evenly spread word timings, so the browser pipeline runs without a key.
    class Fake < Base
      VOICES = [
        Voice.new(id: "fake-alto", name: "Fake Alto", labels: { "gender" => "female" }),
        Voice.new(id: "fake-tenor", name: "Fake Tenor", labels: { "gender" => "male" }),
        Voice.new(id: "fake-mezzo", name: "Fake Mezzo", labels: { "gender" => "female" })
      ].freeze
      SAMPLE_RATE = 8_000
      MS_PER_CHAR = 55
      MIN_MS = 1_200

      def voices
        VOICES
      end

      def synthesize(text:, voice_id:, language: nil)
        duration_ms = [ text.length * MS_PER_CHAR, MIN_MS ].max
        words = text.split(/\s+/)
        slot = duration_ms.to_f / [ words.size, 1 ].max
        timings = words.each_with_index.map do |word, index|
          { "word" => word, "start_ms" => (index * slot).round, "end_ms" => ((index + 1) * slot).round }
        end
        Result.new(audio: silent_wav(duration_ms), mime: "audio/wav", duration_ms: duration_ms, timings: timings)
      end

      private

      def silent_wav(duration_ms)
        samples = SAMPLE_RATE * duration_ms / 1000
        data = "\x00".b * (samples * 2)
        header = [ "RIFF", 36 + data.bytesize, "WAVE", "fmt ", 16, 1, 1, SAMPLE_RATE, SAMPLE_RATE * 2, 2, 16, "data", data.bytesize ]
        header.pack("a4Va4a4VvvVVvva4V") + data
      end
    end
  end
end
