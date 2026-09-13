module Api
  module Admin
    class VoicesController < BaseController
      CACHE_TTL = 10.minutes

      def index
        config = AppConfig.current
        voices = Rails.cache.fetch([ "tts-voices", config.tts_provider ], expires_in: CACHE_TTL) do
          Providers::Registry.tts(config).voices.map(&:to_h)
        end
        render json: { voices: voices }
      end
    end
  end
end
