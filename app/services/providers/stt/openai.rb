module Providers
  module Stt
    class Openai < Base
      RECOVERABLE = [ OpenAI::Errors::APIConnectionError, OpenAI::Errors::RateLimitError, OpenAI::Errors::InternalServerError ].freeze
      REALTIME_URL = "wss://api.openai.com/v1/realtime?intent=transcription".freeze
      REALTIME_SAMPLE_RATE = 24_000
      PREVIEW_TOKEN_SECONDS = 600
      PREVIEW_MODEL = "gpt-4o-mini-transcribe".freeze

      def transcribe(audio:, mime:, filename:, language: nil)
        response = client.audio.transcriptions.create(**request_params(audio, mime, filename, language))
        Result.new(text: response.text.to_s.strip, language: language_of(response), duration_ms: duration_of(response))
      rescue *RECOVERABLE => e
        raise Error.new("OpenAI transcription failed: #{e.class.name.demodulize}", recoverable: true)
      rescue OpenAI::Errors::APIError => e
        raise Error.new("OpenAI rejected the audio: #{e.class.name.demodulize}", recoverable: false)
      end

      # A short-lived key lets the browser stream audio to the Realtime API itself; the main key never leaves the server.
      def live_preview(language: nil)
        return nil if setting("live_preview") == false

        response = client.realtime.client_secrets.create(
          expires_after: { anchor: "created_at", seconds: PREVIEW_TOKEN_SECONDS },
          session: preview_session(language)
        )
        Preview.new(kind: "openai_realtime", url: setting("preview_url").presence || REALTIME_URL,
                    token: response.value, expires_at: response.expires_at, sample_rate: REALTIME_SAMPLE_RATE)
      rescue *RECOVERABLE => e
        raise Error.new("OpenAI preview key failed: #{e.class.name.demodulize}", recoverable: true)
      rescue OpenAI::Errors::APIError => e
        raise Error.new("OpenAI refused the preview key: #{e.class.name.demodulize}", recoverable: false)
      end

      private

      def preview_session(language)
        transcription = { model: preview_model, language: language.presence, prompt: setting("prompt").presence }.compact
        {
          type: "transcription",
          audio: {
            input: {
              format: { type: "audio/pcm", rate: REALTIME_SAMPLE_RATE },
              noise_reduction: { type: "near_field" },
              transcription: transcription,
              turn_detection: { type: "server_vad", threshold: 0.5, prefix_padding_ms: 300, silence_duration_ms: 500 }
            }
          }
        }
      end

      # The batch model stays the source of truth; streaming uses the same family unless the admin picks another.
      def preview_model
        setting("preview_model").presence || (config.stt_model.to_s.start_with?("gpt-") ? config.stt_model : PREVIEW_MODEL)
      end

      def setting(key)
        config.stt_settings.is_a?(Hash) ? config.stt_settings[key] : nil
      end

      def request_params(audio, mime, filename, language)
        params = {
          file: OpenAI::FilePart.new(StringIO.new(audio), filename: filename, content_type: mime),
          model: config.stt_model,
          response_format: whisper? ? :verbose_json : :json
        }
        params[:language] = language if language.present?
        prompt = setting("prompt").presence
        params[:prompt] = prompt if prompt
        params
      end

      def whisper?
        config.stt_model.to_s.start_with?("whisper")
      end

      def language_of(response)
        return response.language if response.respond_to?(:language) && response.language.present?

        response.languages&.first&.code if response.respond_to?(:languages)
      end

      def duration_of(response)
        (response.duration * 1000).round if response.respond_to?(:duration) && response.duration
      end

      def client
        @client ||= OpenAI::Client.new(api_key: api_key, timeout: timeout_seconds, max_retries: 0)
      end

      def api_key
        ENV["OPENAI_API_KEY"].presence || raise(MissingCredentials, "OPENAI_API_KEY")
      end

      def timeout_seconds
        ENV.fetch("STT_TIMEOUT_MS", 15_000).to_i / 1000.0
      end
    end
  end
end
