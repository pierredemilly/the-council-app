# == Schema Information
#
# Table name: app_configs
#
#  id                       :bigint           not null, primary key
#  fallback_language        :string           default("en"), not null
#  global_system_prompt     :text             default(""), not null
#  inactivity_reset_seconds :integer          default(300), not null
#  llm_model                :string           default("gpt-5.6-luna"), not null
#  llm_provider             :string           default("openai"), not null
#  max_ai_turns             :integer          default(6), not null
#  operating_mode           :string           default("cloud_pi"), not null
#  reasoning_level          :string           default("none"), not null
#  resume_window_seconds    :integer          default(600), not null
#  retry_base_ms            :integer          default(500), not null
#  retry_count              :integer          default(3), not null
#  retry_max_ms             :integer          default(4000), not null
#  stt_model                :string           default("gpt-4o-transcribe"), not null
#  stt_provider             :string           default("openai"), not null
#  stt_settings             :jsonb            not null
#  tts_model                :string           default("eleven_v3"), not null
#  tts_provider             :string           default("eleven_labs"), not null
#  tts_settings             :jsonb            not null
#  turn_gap_ms              :integer          default(700), not null
#  vad_settings             :jsonb            not null
#  yield_grace_ms           :integer          default(2500), not null
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#
class AppConfigSerializer
  include Alba::Resource

  attributes :id, :global_system_prompt, :llm_provider, :llm_model, :reasoning_level,
             :stt_provider, :stt_model, :stt_settings, :tts_provider, :tts_model, :tts_settings,
             :max_ai_turns, :inactivity_reset_seconds, :resume_window_seconds, :yield_grace_ms, :turn_gap_ms,
             :retry_count, :retry_base_ms, :retry_max_ms, :vad_settings, :operating_mode,
             :fallback_language, :updated_at
end
