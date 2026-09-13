namespace :e2e do
  desc "Point the live configuration at the fake providers for browser tests"
  task seed: :environment do
    Rails.application.load_seed
    AppConfig.current.update!(
      llm_provider: "fake", tts_provider: "fake", stt_provider: "fake",
      stt_settings: { "fake_text" => "Hello from the fake microphone" },
      inactivity_reset_seconds: 30, resume_window_seconds: 60, yield_grace_ms: 500
    )
    Agent.ordered.each_with_index { |agent, index| agent.update!(voice_id: %w[fake-alto fake-mezzo fake-tenor][index]) }
    ConversationSession.delete_all
  end
end
