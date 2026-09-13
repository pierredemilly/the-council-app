module Providers
  module Tts
    class Base
      def initialize(config)
        @config = config
      end

      def voices
        raise NotImplementedError
      end

      private

      attr_reader :config
    end
  end
end
