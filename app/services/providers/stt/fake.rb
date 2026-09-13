module Providers
  module Stt
    # Returns a configurable line so the microphone path runs without a key (stt_settings.fake_text).
    class Fake < Base
      DEFAULT_TEXT = "Hello from the fake microphone".freeze
      BYTES_PER_MS = 32

      def transcribe(audio:, mime:, filename:, language: nil)
        text = config.stt_settings.is_a?(Hash) ? config.stt_settings["fake_text"].presence : nil
        Result.new(text: text || DEFAULT_TEXT, language: language || "en", duration_ms: audio.bytesize / BYTES_PER_MS)
      end
    end
  end
end
