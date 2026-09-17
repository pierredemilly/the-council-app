namespace :e2e do
  desc "Point the live configuration at the fake providers for browser tests"
  task seed: :environment do
    Rails.application.load_seed
    AppConfig.current.update!(
      llm_provider: "fake", tts_provider: "fake", stt_provider: "fake",
      stt_settings: { "fake_text" => "Hello from the fake microphone" },
      inactivity_reset_seconds: 30, resume_window_seconds: 60, yield_grace_ms: 500,
      vad_settings: AppConfig::DEFAULT_VAD_SETTINGS
    )
    User.find_or_create_by!(email: "admin@example.com") { |user| user.password = "password123" }
    Agent.ordered.each_with_index { |agent, index| agent.update!(voice_id: %w[fake-alto fake-mezzo fake-tenor][index]) }
    Agent.ordered.first.update!(biography: "Playwright, poet and spy.")
    ConversationSession.destroy_all
  end
end
