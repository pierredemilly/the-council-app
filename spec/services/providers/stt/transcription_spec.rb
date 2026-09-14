require "rails_helper"

RSpec.describe "STT adapters" do
  let(:wav) { Providers::Tts::Fake.new(AppConfig.current).synthesize(text: "hello there", voice_id: "x").audio }

  describe Providers::Stt::Fake do
    it "offers a fake live preview carrying the same line" do
      AppConfig.current.update!(stt_settings: { "fake_text" => "Bonjour le conseil" })
      preview = described_class.new(AppConfig.current).live_preview(language: "fr")
      expect(preview.kind).to eq("fake")
      expect(preview.text).to eq("Bonjour le conseil")
    end

    it "returns the configured line and estimates the duration" do
      AppConfig.current.update!(stt_settings: { "fake_text" => "Bonjour le conseil" })
      result = described_class.new(AppConfig.current).transcribe(audio: wav, mime: "audio/wav", filename: "u.wav", language: "fr")
      expect(result.text).to eq("Bonjour le conseil")
      expect(result.language).to eq("fr")
      expect(result.duration_ms).to be_within(50).of(600)
    end
  end

  describe Providers::Stt::Openai do
    around do |example|
      original = ENV["OPENAI_API_KEY"]
      ENV["OPENAI_API_KEY"] = "sk-test"
      example.run
      ENV["OPENAI_API_KEY"] = original
    end

    it "mints a short-lived realtime key for the browser preview without exposing the API key" do
      config = AppConfig.current.tap { |c| c.update!(stt_model: "gpt-4o-transcribe", stt_settings: { "prompt" => "Names: Aphra" }) }
      stub = stub_request(:post, "https://api.openai.com/v1/realtime/client_secrets")
        .with(headers: { "Authorization" => "Bearer sk-test" }) { |request|
          body = JSON.parse(request.body)
          input = body.dig("session", "audio", "input")
          body.dig("expires_after", "seconds") == 600 &&
            body.dig("session", "type") == "transcription" &&
            input.dig("format", "rate") == 24_000 &&
            input.dig("transcription", "model") == "gpt-4o-transcribe" &&
            input.dig("transcription", "language") == "fr" &&
            input.dig("transcription", "prompt") == "Names: Aphra" &&
            input.dig("turn_detection", "type") == "server_vad"
        }
        .to_return(status: 200, headers: { "Content-Type" => "application/json" },
                   body: { value: "ek_test_123", expires_at: 1_800_000_000, session: { type: "transcription", id: "sess_1", object: "realtime.transcription_session" } }.to_json)

      preview = described_class.new(config).live_preview(language: "fr")

      expect(stub).to have_been_requested
      expect(preview.kind).to eq("openai_realtime")
      expect(preview.token).to eq("ek_test_123")
      expect(preview.url).to start_with("wss://api.openai.com/v1/realtime")
      expect(preview.sample_rate).to eq(24_000)
      expect(preview.expires_at).to eq(1_800_000_000)
    end

    it "falls back to the streaming model when the batch model cannot stream, and can be switched off" do
      config = AppConfig.current.tap { |c| c.update!(stt_model: "whisper-1") }
      stub = stub_request(:post, "https://api.openai.com/v1/realtime/client_secrets") { |request|
        JSON.parse(request.body).dig("session", "audio", "input", "transcription", "model") == "gpt-4o-mini-transcribe"
      }.to_return(status: 200, headers: { "Content-Type" => "application/json" },
                  body: { value: "ek_x", expires_at: 1, session: { type: "transcription" } }.to_json)

      expect(described_class.new(config).live_preview.token).to eq("ek_x")
      expect(stub).to have_been_requested

      config.update!(stt_settings: { "live_preview" => false })
      expect(described_class.new(config).live_preview).to be_nil
    end

    it "uploads the audio as multipart and reads text and detected language" do
      config = AppConfig.current.tap { |c| c.update!(stt_model: "gpt-4o-transcribe", stt_settings: { "prompt" => "Names: Aphra, Rosa, Claudia" }) }
      stub = stub_request(:post, "https://api.openai.com/v1/audio/transcriptions")
        .with(headers: { "Authorization" => "Bearer sk-test" }) { |request|
          body = request.body
          body.include?('name="model"') && body.include?("gpt-4o-transcribe") && body.include?("Names: Aphra") &&
            body.include?('filename="u.wav"') && body.include?("RIFF") && !body.include?('name="language"')
        }
        .to_return(status: 200, headers: { "Content-Type" => "application/json" }, body: { text: " Good evening ", languages: [ { code: "en", confidence: 0.98 } ] }.to_json)

      result = described_class.new(config).transcribe(audio: wav, mime: "audio/wav", filename: "u.wav")

      expect(stub).to have_been_requested
      expect(result.text).to eq("Good evening")
      expect(result.language).to eq("en")
    end

    it "asks whisper for verbose json and forwards the language hint" do
      config = AppConfig.current.tap { |c| c.update!(stt_model: "whisper-1") }
      stub = stub_request(:post, "https://api.openai.com/v1/audio/transcriptions") { |request|
        request.body.include?("verbose_json") && request.body.include?('name="language"') && request.body.include?("fr")
      }.to_return(status: 200, headers: { "Content-Type" => "application/json" }, body: { task: "transcribe", text: "Bonsoir", language: "french", duration: 1.4, segments: [] }.to_json)

      result = described_class.new(config).transcribe(audio: wav, mime: "audio/wav", filename: "u.wav", language: "fr")

      expect(stub).to have_been_requested
      expect(result.text).to eq("Bonsoir")
      expect(result.duration_ms).to eq(1400)
    end

    it "maps failures like the other OpenAI adapter" do
      config = AppConfig.current
      stub_request(:post, "https://api.openai.com/v1/audio/transcriptions").to_return(status: 500, body: "{}", headers: { "Content-Type" => "application/json" })
      expect { described_class.new(config).transcribe(audio: wav, mime: "audio/wav", filename: "u.wav") }.to raise_error(Providers::Error) { |e| expect(e.recoverable).to be(true) }

      stub_request(:post, "https://api.openai.com/v1/audio/transcriptions").to_return(status: 400, body: "{}", headers: { "Content-Type" => "application/json" })
      expect { described_class.new(config).transcribe(audio: wav, mime: "audio/wav", filename: "u.wav") }.to raise_error(Providers::Error) { |e| expect(e.recoverable).to be(false) }
    end
  end
end
