module Providers
  module Stt
    # Returns a configurable line so the microphone path runs without a key (stt_settings.fake_text).
    class Fake < Base
      DEFAULT_TEXT = "Hello from the fake microphone".freeze
      BYTES_PER_MS = 32

      def transcribe(audio:, mime:, filename:, language: nil)
        Result.new(text: fake_text, language: language || "en", duration_ms: audio.bytesize / BYTES_PER_MS)
      end

      def live_preview(language: nil)
        Preview.new(kind: "fake", text: fake_text)
      end

      private

      def fake_text
        text = config.stt_settings.is_a?(Hash) ? config.stt_settings["fake_text"].presence : nil
        text || DEFAULT_TEXT
      end
    end
  end
end
