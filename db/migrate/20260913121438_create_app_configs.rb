class CreateAppConfigs < ActiveRecord::Migration[8.0]
  def change
    create_table :app_configs do |t|
      t.text :global_system_prompt, null: false, default: ""
      t.string :llm_provider, null: false, default: "openai"
      t.string :llm_model, null: false, default: "gpt-5.6-luna"
      t.string :reasoning_level, null: false, default: "none"
      t.string :stt_provider, null: false, default: "openai"
      t.string :stt_model, null: false, default: "gpt-4o-transcribe"
      t.jsonb :stt_settings, null: false, default: {}
      t.string :tts_provider, null: false, default: "eleven_labs"
      t.string :tts_model, null: false, default: "eleven_v3"
      t.jsonb :tts_settings, null: false, default: {}
      t.integer :max_ai_turns, null: false, default: 6
      t.integer :inactivity_reset_seconds, null: false, default: 300
      t.integer :resume_window_seconds, null: false, default: 600
      t.integer :yield_grace_ms, null: false, default: 2500
      t.integer :retry_count, null: false, default: 3
      t.integer :retry_base_ms, null: false, default: 500
      t.integer :retry_max_ms, null: false, default: 4000
      t.jsonb :vad_settings, null: false, default: {}
      t.string :operating_mode, null: false, default: "cloud_pi"
      t.string :fallback_language, null: false, default: "en"

      t.timestamps
    end
  end
end
