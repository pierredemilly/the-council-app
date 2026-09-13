module Providers
  module Stt
    class Openai < Base
      RECOVERABLE = [ OpenAI::Errors::APIConnectionError, OpenAI::Errors::RateLimitError, OpenAI::Errors::InternalServerError ].freeze

      def transcribe(audio:, mime:, filename:, language: nil)
        response = client.audio.transcriptions.create(**request_params(audio, mime, filename, language))
        Result.new(text: response.text.to_s.strip, language: language_of(response), duration_ms: duration_of(response))
      rescue *RECOVERABLE => e
        raise Error.new("OpenAI transcription failed: #{e.class.name.demodulize}", recoverable: true)
      rescue OpenAI::Errors::APIError => e
        raise Error.new("OpenAI rejected the audio: #{e.class.name.demodulize}", recoverable: false)
      end

      private

      def request_params(audio, mime, filename, language)
        params = {
          file: OpenAI::FilePart.new(StringIO.new(audio), filename: filename, content_type: mime),
          model: config.stt_model,
          response_format: whisper? ? :verbose_json : :json
        }
        params[:language] = language if language.present?
        prompt = config.stt_settings.is_a?(Hash) ? config.stt_settings["prompt"].presence : nil
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
