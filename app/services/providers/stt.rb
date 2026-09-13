# Value objects shared by every STT adapter.
module Providers
  module Stt
    Result = Data.define(:text, :language, :duration_ms) do
      def initialize(text:, language: nil, duration_ms: nil)
        super
      end
    end
  end
end
