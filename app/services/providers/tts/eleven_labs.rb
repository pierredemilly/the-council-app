module Providers
  module Tts
    class ElevenLabs < Base
      BASE_URL = "https://api.elevenlabs.io/v1".freeze

      def voices
        body = get("/voices")
        body.fetch("voices", []).map do |voice|
          Voice.new(
            id: voice["voice_id"],
            name: voice["name"],
            preview_url: voice["preview_url"],
            labels: voice["labels"] || {}
          )
        end
      end

      private

      def get(path)
        response = HTTParty.get("#{BASE_URL}#{path}", headers: headers, timeout: timeout_seconds)
        raise Error.new("ElevenLabs responded #{response.code}", recoverable: response.code >= 500) unless response.success?

        response.parsed_response
      rescue HTTParty::Error, Timeout::Error, SocketError => e
        raise Error.new("ElevenLabs request failed: #{e.class}")
      end

      def headers
        { "xi-api-key" => api_key, "Accept" => "application/json" }
      end

      def api_key
        ENV["ELEVENLABS_API_KEY"].presence || raise(MissingCredentials, "ELEVENLABS_API_KEY")
      end

      def timeout_seconds
        ENV.fetch("TTS_TIMEOUT_MS", 20_000).to_i / 1000.0
      end
    end
  end
end
