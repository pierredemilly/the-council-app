module Providers
  module Tts
    class Base
      # Bracketed cues the provider can voice; anything else is rejected by the script parser.
      STAGE_DIRECTIONS = %w[laughs chuckles sighs whispers pause hesitates].freeze

      def initialize(config)
        @config = config
      end

      def voices
        raise NotImplementedError
      end

      def synthesize(text:, voice_id:, language: nil)
        raise NotImplementedError
      end

      def stage_directions
        self.class::STAGE_DIRECTIONS
      end

      private

      attr_reader :config
    end
  end
end
