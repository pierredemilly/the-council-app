require "rails_helper"

# == Schema Information
#
# Table name: app_configs
#
#  id                       :bigint           not null, primary key
#  continue_grace_ms        :integer          default(2000), not null
#  fallback_language        :string           default("en"), not null
#  global_system_prompt     :text             default(""), not null
#  inactivity_reset_seconds :integer          default(300), not null
#  llm_model                :string           default("gpt-5.6-luna"), not null
#  llm_provider             :string           default("openai"), not null
#  max_ai_turns             :integer          default(6), not null
#  max_unprompted_segments  :integer          default(2), not null
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
#  yield_grace_ms           :integer          default(5000), not null
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#
RSpec.describe AppConfig, type: :model do
  describe ".current" do
    it "creates the singleton on first access and reuses it afterwards" do
      expect { AppConfig.current }.to change(AppConfig, :count).from(0).to(1)
      expect(AppConfig.current).to eq(AppConfig.first)
      expect(AppConfig.count).to eq(1)
    end

    it "starts with the default VAD thresholds" do
      expect(AppConfig.current.vad_settings).to include("positive_speech_threshold" => 0.5, "min_speech_ms" => 250)
    end
  end

  describe "validations" do
    subject(:config) { AppConfig.current }

    it "caps the number of AI turns at six" do
      config.max_ai_turns = 7
      expect(config).not_to be_valid
      expect(config.errors[:max_ai_turns]).to be_present
    end

    it "rejects unknown providers and reasoning levels" do
      config.assign_attributes(tts_provider: "polly", reasoning_level: "ultra")
      expect(config).not_to be_valid
      expect(config.errors.attribute_names).to contain_exactly(:tts_provider, :reasoning_level)
    end

    it "requires the maximum backoff to be at least the base backoff" do
      config.assign_attributes(retry_base_ms: 2000, retry_max_ms: 1000)
      expect(config).not_to be_valid
      expect(config.errors[:retry_max_ms]).to be_present
    end

    it "rejects provider settings that are not small JSON objects" do
      config.stt_settings = [ 1, 2 ]
      expect(config).not_to be_valid

      config.stt_settings = { "blob" => "x" * 5.kilobytes }
      expect(config).not_to be_valid
    end

    it "keeps VAD values inside the slider ranges" do
      config.vad_settings = config.vad_settings.merge("positive_speech_threshold" => 1.5)
      expect(config).not_to be_valid

      config.vad_settings = config.vad_settings.merge("positive_speech_threshold" => 0.3, "negative_speech_threshold" => 0.6)
      expect(config).not_to be_valid

      config.vad_settings = config.vad_settings.merge("positive_speech_threshold" => 0.6, "negative_speech_threshold" => 0.3, "redemption_ms" => 900)
      expect(config).to be_valid
    end
  end
end
