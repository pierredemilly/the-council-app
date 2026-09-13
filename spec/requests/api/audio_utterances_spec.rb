require "rails_helper"

RSpec.describe "Audio utterances API", type: :request do
  let(:session) { create_conversation }
  let(:headers) { { "X-Session-Token" => session.client_token } }

  def wav_upload(text: "hello there", type: "audio/wav")
    bytes = Providers::Tts::Fake.new(AppConfig.current).synthesize(text: text, voice_id: "x").audio
    file = Tempfile.new([ "utterance", ".wav" ], binmode: true)
    file.write(bytes)
    file.rewind
    Rack::Test::UploadedFile.new(file.path, type)
  end

  def json
    JSON.parse(response.body)
  end

  it "transcribes the upload, pins the session language and starts the discussion with STT latency" do
    AppConfig.current.update!(stt_settings: { "fake_text" => "Bonsoir à tous" })
    session

    post "/api/sessions/#{session.id}/utterances", params: { audio: wav_upload }, headers: headers

    expect(response).to have_http_status(:accepted)
    expect(json.dig("event", "text")).to eq("Bonsoir à tous")
    expect(json["language"]).to eq("en")
    event = session.reload.events.first
    expect(event.latency.keys).to include("stt_ms", "audio_ms")
    expect(session.language).to eq("en")
    expect(session.turns.count).to eq(3)
  end

  it "rejects unsupported, empty or oversized audio" do
    post "/api/sessions/#{session.id}/utterances", params: { audio: wav_upload(type: "text/plain") }, headers: headers
    expect(response).to have_http_status(:unprocessable_content)
    expect(json["code"]).to eq("invalid_audio")

    stub_const("Conversation::Transcriber::AUDIO_BYTE_LIMIT", 10)
    post "/api/sessions/#{session.id}/utterances", params: { audio: wav_upload }, headers: headers
    expect(response).to have_http_status(:unprocessable_content)
    expect(json["error"]).to include("too large")
  end

  it "answers no_speech when the transcript is empty so the client can resume" do
    AppConfig.current.update!(stt_settings: { "fake_text" => "   " })
    allow_any_instance_of(Providers::Stt::Fake).to receive(:transcribe).and_return(Providers::Stt::Result.new(text: "  "))

    post "/api/sessions/#{session.id}/utterances", params: { audio: wav_upload }, headers: headers

    expect(response).to have_http_status(:unprocessable_content)
    expect(json["code"]).to eq("no_speech")
    expect(session.reload.events.count).to eq(0)
  end

  it "reports provider failures as a retryable bad gateway" do
    AppConfig.current.update!(retry_count: 0)
    allow_any_instance_of(Providers::Stt::Fake).to receive(:transcribe).and_raise(Providers::Error.new("stt down", recoverable: true))

    post "/api/sessions/#{session.id}/utterances", params: { audio: wav_upload }, headers: headers

    expect(response).to have_http_status(:bad_gateway)
    expect(json).to include("code" => "transcription_failed", "retryable" => true)
  end
end
