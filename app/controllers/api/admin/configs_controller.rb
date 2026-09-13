module Api
  module Admin
    class ConfigsController < BaseController
      def show
        render json: config_payload
      end

      def update
        config = AppConfig.current
        if config.update(config_params)
          render json: config_payload(config)
        else
          render_invalid(config)
        end
      end

      private

      def config_payload(config = AppConfig.current)
        {
          config: AppConfigSerializer.new(config).serializable_hash,
          options: {
            llm_providers: AppConfig::LLM_PROVIDERS,
            stt_providers: AppConfig::STT_PROVIDERS,
            tts_providers: AppConfig::TTS_PROVIDERS,
            reasoning_levels: AppConfig::REASONING_LEVELS,
            operating_modes: AppConfig::OPERATING_MODES
          }
        }
      end

      def config_params
        params.require(:config).permit(
          :global_system_prompt, :llm_provider, :llm_model, :reasoning_level,
          :stt_provider, :stt_model, :tts_provider, :tts_model,
          :max_ai_turns, :inactivity_reset_seconds, :resume_window_seconds, :yield_grace_ms,
          :retry_count, :retry_base_ms, :retry_max_ms, :operating_mode, :fallback_language,
          stt_settings: {}, tts_settings: {}, vad_settings: {}
        )
      end
    end
  end
end
