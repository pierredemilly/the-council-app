export const en = {
  app: {
    name: "The Council",
  },
  common: {
    error: "Error",
    close: "Close",
    save: "Save",
    saving: "Saving...",
    loading: "Loading…",
  },
  admin: {
    open: "Open the admin",
    sign_out: "Sign out",
    saved: "Saved.",
    json_invalid: "Invalid JSON: the last valid value will be saved.",
    nav: {
      settings: "Settings",
      characters: "Characters",
    },
    settings: {
      title: "Live configuration",
      intro:
        "Changes apply to new conversations immediately. Running conversations keep the configuration they started with.",
      prompt: "Conversation",
      global_system_prompt: "Global system prompt",
      global_system_prompt_hint:
        "The editorial brief shared by all three characters. Structural rules (turn limits, output format) are added automatically.",
      fallback_language: "Fallback language",
      llm: "Dialogue model (LLM)",
      stt: "Speech to text (STT)",
      tts: "Text to speech (TTS)",
      provider: "Provider",
      model: "Model",
      reasoning_level: "Reasoning level",
      max_ai_turns: "Maximum AI turns per segment",
      max_ai_turns_hint:
        "Between 1 and 6. Each character speaks at most twice per segment.",
      provider_settings: "Provider settings (JSON)",
      provider_settings_hint:
        "Passed to the provider as is, for example voice stability or transcription hints.",
      timing: "Timing",
      inactivity_reset_seconds: "Kiosk inactivity reset (seconds)",
      inactivity_reset_seconds_hint:
        "Kiosk mode only: an idle conversation resets after this delay.",
      resume_window_seconds: "Resume window (seconds)",
      resume_window_seconds_hint:
        "A closed page can resume its conversation for this long.",
      yield_grace_ms: "Yield grace period (ms)",
      yield_grace_ms_hint:
        "Silence tolerated after a natural opening before the characters carry on.",
      retries: "Provider retries",
      retry_count: "Retry count",
      retry_base_ms: "Base backoff (ms)",
      retry_max_ms: "Maximum backoff (ms)",
      vad: "Voice activity detection",
      vad_settings: "VAD thresholds (JSON)",
      vad_settings_hint:
        "Installation-specific. Thresholds are probabilities between 0 and 1; durations are in milliseconds.",
      deployment: "Deployment",
      operating_mode: "Operating mode",
      operating_mode_hint:
        "Metadata for the installation; it does not change behaviour in V1.",
      operating_modes: {
        cloud_pi: "Cloud only (Raspberry Pi client)",
        local_gpu: "Local-server capable (GPU computer)",
      },
    },
    characters: {
      title: "Characters",
      intro:
        "The three characters of the council. Names must be unique and cannot contain colons.",
      voices_error: "Voices could not be loaded: {error}",
      name: "Name",
      voice: "Voice",
      no_voice: "No voice selected",
      personality: "Personality sheet",
      personality_hint:
        "Long-form. Biography, beliefs, vocabulary, habits, how this character disagrees.",
      upload_avatar: "Upload avatar",
      remove_avatar: "Remove avatar",
    },
  },
};
