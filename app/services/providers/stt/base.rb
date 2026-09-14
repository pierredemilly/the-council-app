module Providers
  module Stt
    class Base
      def initialize(config)
        @config = config
      end

      # language: ISO 639-1 hint once the session knows it; nil lets the provider detect.
      def transcribe(audio:, mime:, filename:, language: nil)
        raise NotImplementedError
      end

      def live_preview(language: nil)
        nil
      end

      private

      attr_reader :config
    end
  end
end
