module Conversation
  # Turns one uploaded utterance into text, pinning the session language on first detection.
  class Transcriber
    AUDIO_BYTE_LIMIT = 5.megabytes
    MIME_TYPES = %w[audio/wav audio/x-wav audio/wave audio/webm audio/ogg audio/mp4 audio/mpeg].freeze

    class Rejected < Conversation::Error; end

    Outcome = Data.define(:text, :language, :stt_ms, :audio_ms)

    def initialize(session, stt: nil)
      @session = session
      @stt = stt || Providers::Registry.stt(session.snapshot)
    end

    def call(upload)
      audio, mime, filename = read(upload)
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC, :millisecond)
      log = ->(error, attempt) { ProviderError.record!(session: @session, stage: "stt", provider: @session.snapshot.stt_provider, error: error, attempt: attempt) }
      result = @session.snapshot.retry_policy.run(on_error: log) do
        @stt.transcribe(audio: audio, mime: mime, filename: filename, language: @session.language)
      end
      stt_ms = Process.clock_gettime(Process::CLOCK_MONOTONIC, :millisecond) - started

      pin_language(result.language)
      Outcome.new(text: result.text.to_s.strip, language: result.language, stt_ms: stt_ms, audio_ms: result.duration_ms)
    end

    private

    def read(upload)
      raise Rejected, "audio is missing" unless upload.respond_to?(:read)

      mime = upload.content_type.to_s.split(";").first.to_s.strip
      raise Rejected, "unsupported audio type #{mime}" unless MIME_TYPES.include?(mime)

      audio = upload.read
      raise Rejected, "audio is empty" if audio.blank?
      raise Rejected, "audio is too large" if audio.bytesize > AUDIO_BYTE_LIMIT

      [ audio, mime, upload.respond_to?(:original_filename) ? upload.original_filename.presence || "utterance" : "utterance" ]
    end

    def pin_language(language)
      code = language.to_s[0, 2].downcase
      return if code.blank? || @session.language.present? || !code.match?(/\A[a-z]{2}\z/)

      @session.update_columns(language: code)
    end
  end
end
