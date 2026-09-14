# Value objects shared by every STT adapter.
module Providers
  module Stt
    Result = Data.define(:text, :language, :duration_ms) do
      def initialize(text:, language: nil, duration_ms: nil)
        super
      end
    end

    # What the browser needs to show a transcript while the visitor is still talking; nil when the adapter cannot stream.
    Preview = Data.define(:kind, :url, :token, :expires_at, :sample_rate, :text) do
      def initialize(kind:, url: nil, token: nil, expires_at: nil, sample_rate: nil, text: nil)
        super
      end
    end
  end
end
