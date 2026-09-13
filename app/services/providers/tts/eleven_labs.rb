module Providers
  module Tts
    class ElevenLabs < Base
      BASE_URL = "https://api.elevenlabs.io/v1".freeze
      OUTPUT_FORMAT = "mp3_44100_128".freeze

      def voices
        body = get("/voices")
        body.fetch("voices", []).map do |voice|
          Voice.new(id: voice["voice_id"], name: voice["name"], preview_url: voice["preview_url"], labels: voice["labels"] || {})
        end
      end

      def synthesize(text:, voice_id:, language: nil)
        raise Error.new("This character has no voice configured", recoverable: false) if voice_id.blank?

        body = { text: text, model_id: config.tts_model }
        body[:voice_settings] = config.tts_settings["voice_settings"] if config.tts_settings.is_a?(Hash) && config.tts_settings["voice_settings"].present?
        body[:language_code] = language if language.present? && !config.tts_model.include?("multilingual_v2")

        response = post("/text-to-speech/#{voice_id}/with-timestamps?output_format=#{OUTPUT_FORMAT}", body)
        alignment = response["alignment"] || {}
        timings = Tts.word_timings(text, alignment["characters"], alignment["character_start_times_seconds"], alignment["character_end_times_seconds"])
        duration_ms = alignment["character_end_times_seconds"]&.last&.then { |s| (s * 1000).round }

        Result.new(audio: Base64.decode64(response.fetch("audio_base64")), mime: "audio/mpeg", duration_ms: duration_ms, timings: timings)
      rescue KeyError
        raise Error.new("ElevenLabs returned no audio", recoverable: true)
      end

      private

      def get(path)
        request { HTTParty.get("#{BASE_URL}#{path}", headers: headers, timeout: timeout_seconds) }
      end

      def post(path, body)
        request do
          HTTParty.post("#{BASE_URL}#{path}", headers: headers.merge("Content-Type" => "application/json"), body: body.to_json, timeout: timeout_seconds)
        end
      end

      def request
        response = yield
        raise Error.new("ElevenLabs responded #{response.code}", recoverable: response.code >= 500 || response.code == 429) unless response.success?

        response.parsed_response
      rescue HTTParty::Error, Timeout::Error, SocketError, Errno::ECONNRESET => e
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
