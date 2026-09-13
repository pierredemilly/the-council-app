module Providers
  module Llm
    class Base
      def initialize(config)
        @config = config
      end

      def generate_segment(_input)
        raise NotImplementedError
      end

      private

      attr_reader :config
    end
  end
end
