module Providers
  module Llm
    class Base
      def initialize(config)
        @config = config
      end

      # feedback: validation error from a previous attempt, when retrying a rejected script.
      def complete(_input, feedback: nil)
        raise NotImplementedError
      end

      private

      attr_reader :config
    end
  end
end
