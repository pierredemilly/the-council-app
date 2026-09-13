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
class AppConfig < ApplicationRecord
  LLM_PROVIDERS = %w[openai fake].freeze
  STT_PROVIDERS = %w[openai fake].freeze
  TTS_PROVIDERS = %w[eleven_labs fake].freeze
  REASONING_LEVELS = %w[none minimal low medium high].freeze
  OPERATING_MODES = %w[cloud_pi local_gpu].freeze
  MAX_AI_TURNS_LIMIT = 6
  SETTINGS_BYTE_LIMIT = 4.kilobytes
  PROMPT_CHAR_LIMIT = 20_000

  DEFAULT_VAD_SETTINGS = {
    "positive_speech_threshold" => 0.5,
    "negative_speech_threshold" => 0.35,
    "min_speech_ms" => 250,
    "redemption_ms" => 600,
    "pre_speech_pad_ms" => 300,
    "interrupt_min_speech_ms" => 300
  }.freeze
  # Ranges the admin sliders and the API both enforce.
  VAD_RANGES = {
    "positive_speech_threshold" => (0.05..0.95),
    "negative_speech_threshold" => (0.05..0.95),
    "min_speech_ms" => (0..2000),
    "redemption_ms" => (0..3000),
    "pre_speech_pad_ms" => (0..1000),
    "interrupt_min_speech_ms" => (0..2000)
  }.freeze

  validates :llm_provider, inclusion: { in: LLM_PROVIDERS }
  validates :stt_provider, inclusion: { in: STT_PROVIDERS }
  validates :tts_provider, inclusion: { in: TTS_PROVIDERS }
  validates :reasoning_level, inclusion: { in: REASONING_LEVELS }
  validates :operating_mode, inclusion: { in: OPERATING_MODES }
  validates :llm_model, :stt_model, :tts_model, presence: true, length: { maximum: 100 }
  validates :fallback_language, format: { with: /\A[a-z]{2}(-[A-Za-z]{2,4})?\z/ }
  validates :global_system_prompt, length: { maximum: PROMPT_CHAR_LIMIT }
  validates :max_ai_turns, numericality: { only_integer: true, in: 1..MAX_AI_TURNS_LIMIT }
  validates :inactivity_reset_seconds, :resume_window_seconds,
            numericality: { only_integer: true, in: 30..3600 }
  validates :yield_grace_ms, numericality: { only_integer: true, in: 0..30_000 }
  validates :turn_gap_ms, numericality: { only_integer: true, in: 0..5_000 }
  validates :retry_count, numericality: { only_integer: true, in: 0..10 }
  validates :retry_base_ms, numericality: { only_integer: true, in: 50..10_000 }
  validates :retry_max_ms, numericality: { only_integer: true, in: 100..60_000 }
  validate :retry_max_not_below_base
  validate :settings_are_small_objects
  validate :vad_settings_in_range

  after_initialize :apply_vad_defaults, if: :new_record?

  def self.current
    first || create!
  end

  private

  def apply_vad_defaults
    self.vad_settings = DEFAULT_VAD_SETTINGS.merge(vad_settings || {})
  end

  def retry_max_not_below_base
    return if retry_max_ms.nil? || retry_base_ms.nil? || retry_max_ms >= retry_base_ms

    errors.add(:retry_max_ms, "must be greater than or equal to the base backoff")
  end

  def vad_settings_in_range
    return unless vad_settings.is_a?(Hash)

    VAD_RANGES.each do |key, range|
      value = vad_settings[key]
      next if value.nil?

      errors.add(:vad_settings, "#{key} must be between #{range.min} and #{range.max}") unless value.is_a?(Numeric) && range.cover?(value)
    end
    if vad_settings["negative_speech_threshold"].is_a?(Numeric) && vad_settings["positive_speech_threshold"].is_a?(Numeric) &&
       vad_settings["negative_speech_threshold"] > vad_settings["positive_speech_threshold"]
      errors.add(:vad_settings, "negative_speech_threshold must not exceed positive_speech_threshold")
    end
  end

  def settings_are_small_objects
    %i[stt_settings tts_settings vad_settings].each do |attribute|
      value = public_send(attribute)
      errors.add(attribute, "must be a JSON object") and next unless value.is_a?(Hash)
      errors.add(attribute, "is too large") if value.to_json.bytesize > SETTINGS_BYTE_LIMIT
    end
  end
end
