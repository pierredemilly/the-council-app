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
      sessions: "Sessions",
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
        "Silence left after a natural pause before the characters carry on by themselves.",
      retries: "Provider retries",
      retry_count: "Retry count",
      retry_base_ms: "Base backoff (ms)",
      retry_max_ms: "Maximum backoff (ms)",
      vad: "Voice activity detection",
      vad_settings: "VAD thresholds (JSON)",
      vad_settings_hint:
        "Installation-specific. Tune on site with the real microphone and loudspeakers; see docs/CALIBRATION.md.",
      deployment: "Deployment",
      operating_mode: "Operating mode",
      operating_mode_hint:
        "Metadata for the installation; it does not change behaviour in V1.",
      operating_modes: {
        cloud_pi: "Cloud only (Raspberry Pi client)",
        local_gpu: "Local-server capable (GPU computer)",
      },
      turn_gap_ms: "Pause between characters (ms)",
      turn_gap_ms_hint:
        "Silence left between two consecutive lines of a segment.",
      vad_sliders: {
        positive_speech_threshold: "Speech threshold",
        positive_speech_threshold_hint:
          "Probability above which a frame counts as speech. Raise it in noisy rooms.",
        negative_speech_threshold: "Silence threshold",
        negative_speech_threshold_hint:
          "Probability below which a frame counts as silence. Keep it under the speech threshold.",
        min_speech_ms: "Minimum speech",
        min_speech_ms_hint: "Shorter bursts (coughs, chairs) are ignored.",
        redemption_ms: "End-of-utterance silence",
        redemption_ms_hint:
          "Silence tolerated inside a sentence before the utterance is considered finished.",
        pre_speech_pad_ms: "Pre-speech padding",
        pre_speech_pad_ms_hint:
          "Audio kept from before the detected start so first syllables are not cut.",
        interrupt_min_speech_ms: "Interruption debounce",
        interrupt_min_speech_ms_hint:
          "Continuous speech needed, while a character talks, before the interruption is confirmed.",
      },
      continue_grace_ms: "Pause before answering each other (ms)",
      continue_grace_ms_hint:
        "Silence left after a line aimed at another character before the group answers it. Long enough for the visitor to step in.",
      max_unprompted_segments: "Segments without the visitor",
      max_unprompted_segments_hint:
        "How many passages the characters may chain among themselves before they stop and wait for the visitor.",
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
      color: "Colour",
      color_hint: "Used for the name in the transcript and the avatar glow.",
    },
    reset: "reset",
    sessions: {
      title: "Sessions",
      intro:
        "The fifty most recent conversations. Open one to read or copy its transcript.",
      empty: "No conversation yet.",
      started: "Started",
      status: "Status",
      turns: "Visitor / characters",
      duration: "Duration",
      first_line: "First line",
      transcript: "Transcript",
      no_events: "Nothing was said.",
      copy: "Copy transcript",
      copied: "Copied!",
      delete: "Delete",
      delete_confirm: "Delete this conversation and its transcript for good?",
      metrics: "Latency",
      metrics_pending: "Aggregated once the conversation is finalized.",
      errors: "Provider errors",
      no_errors: "No provider error.",
    },
  },
  conversation: {
    idle_hint:
      "Three characters are waiting for you. Start the conversation and speak first: they will answer.",
    title: "You stand before the council.",
    start: "Ask a question",
    speak_first:
      "Say something to begin. The characters answer once you have spoken.",
    type_placeholder: "Type what you want to say…",
    send: "Send",
    interrupt: "Interrupt",
    retry: "Try again",
    finished: "This conversation has ended.",
    new_conversation: "Start a new conversation",
    transcript: "Transcript",
    transcript_empty: "The transcript will appear here.",
    you: "You",
    admin: "Admin",
    leave: "Leave",
    kiosk_mode: "Kiosk mode",
    status: {
      starting: "Connecting…",
      listening: "Listening",
      processing: "Thinking…",
      speaking: "Speaking",
      errored: "Something went wrong",
      reconnecting: "Reconnecting…",
      finalized: "Ended",
      user_speaking: "You're speaking",
    },
    enable_sound: "Enable sound",
    mic: {
      starting: "Starting microphone…",
      on: "Microphone on",
      denied: "Microphone unavailable: type instead",
      retry: "Allow microphone",
    },
    reconnecting_hint: "Connection lost, trying to reconnect…",
    connection_lost: "Still no connection.",
    retry_connection: "Retry connection",
    text_only: "Text only",
    sound_on: "Sound on",
    tune: {
      open: "Voice detection",
      title: "Voice detection, live",
      hint_live:
        "Changes apply to this microphone at once. Save to make them the default for every new conversation.",
      hint_idle:
        "Start a conversation to hear the effect. Saved values apply to every new conversation.",
      meter: "Speech probability",
      speech_detected: "Speech detected",
      save: "Save as default",
      saved: "Saved.",
      unsaved: "Applied here, not saved yet.",
      revert: "Revert",
      close: "Close",
    },
  },
};
