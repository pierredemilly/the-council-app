module Api
  class TranscriptionPreviewsController < BaseController
    rate_limit to: 30, within: 1.minute, with: -> { render json: { error: "Too many preview requests" }, status: :too_many_requests }

    # The preview is a nicety: when the provider cannot stream, the browser simply shows nothing while the visitor talks.
    def create
      preview = Providers::Registry.stt(current_session.snapshot).live_preview(language: current_session.language)
      render json: { preview: preview&.to_h&.compact }
    rescue Providers::Error => error
      ProviderError.record!(session: current_session, stage: "stt_preview", provider: current_session.snapshot.stt_provider, error: error)
      render json: { preview: nil }
    end
  end
end
