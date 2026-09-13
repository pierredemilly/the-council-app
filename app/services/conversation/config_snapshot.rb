module Conversation
  # Frozen copy of the live configuration taken when a session starts.
  class ConfigSnapshot
    CONFIG_KEYS = %w[
      global_system_prompt llm_provider llm_model reasoning_level stt_provider stt_model stt_settings
      tts_provider tts_model tts_settings max_ai_turns inactivity_reset_seconds resume_window_seconds
      yield_grace_ms turn_gap_ms retry_count retry_base_ms retry_max_ms vad_settings operating_mode fallback_language
    ].freeze
    AGENT_KEYS = %w[id position name personality voice_id voice_name color].freeze

    def self.capture(config = AppConfig.current, agents = Agent.ordered.with_attached_avatar)
      {
        "captured_at" => Time.current.iso8601(3),
        "config" => config.attributes.slice(*CONFIG_KEYS),
        "agents" => agents.map { |agent| agent.attributes.slice(*AGENT_KEYS).merge("avatar_url" => avatar_url(agent)) }
      }
    end

    def self.avatar_url(agent)
      Rails.application.routes.url_helpers.rails_blob_path(agent.avatar, only_path: true) if agent.avatar.attached?
    end

    def initialize(data)
      @data = data || {}
    end

    CONFIG_KEYS.each do |key|
      define_method(key) { config[key] }
    end

    def config
      @data.fetch("config", {})
    end

    def agents
      @data.fetch("agents", [])
    end

    def agent_names
      agents.map { |agent| agent["name"] }
    end

    def retry_policy
      RetryPolicy.new(count: retry_count, base_ms: retry_base_ms, max_ms: retry_max_ms)
    end

    # What the browser is allowed to see: no personality sheets, no provider details.
    def public_payload
      {
        agents: agents.map { |agent| agent.slice("position", "name", "avatar_url", "color") },
        vad_settings: vad_settings,
        yield_grace_ms: yield_grace_ms,
        turn_gap_ms: turn_gap_ms,
        inactivity_reset_seconds: inactivity_reset_seconds,
        resume_window_seconds: resume_window_seconds,
        fallback_language: fallback_language
      }
    end
  end
end
