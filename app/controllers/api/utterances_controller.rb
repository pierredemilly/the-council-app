module Api
  class UtterancesController < BaseController
    rate_limit to: 60, within: 1.minute, with: -> { render json: { error: "Too many utterances" }, status: :too_many_requests }

    rescue_from Conversation::Transcriber::Rejected do |error|
      render json: { error: error.message, code: "invalid_audio" }, status: :unprocessable_content
    end

    rescue_from Providers::Error do |error|
      render json: { error: error.message, code: "transcription_failed", retryable: error.recoverable }, status: :bad_gateway
    end

    def create
      text, latency = params[:audio].present? ? transcribe : [ params[:text], {} ]
      if text.blank?
        render json: { error: "No speech was recognized", code: "no_speech" }, status: :unprocessable_content
        return
      end

      event = Conversation::Orchestrator.new(current_session).start_from_utterance!(text: text, latency: latency)
      render json: { event: ConversationEventSerializer.new(event).serializable_hash, language: current_session.language }, status: :accepted
    end

    private

    def transcribe
      outcome = Conversation::Transcriber.new(current_session).call(params[:audio])
      [ outcome.text, { "stt_ms" => outcome.stt_ms, "audio_ms" => outcome.audio_ms }.compact ]
    end
  end
end
