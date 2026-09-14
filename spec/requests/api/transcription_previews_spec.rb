require "rails_helper"

RSpec.describe "Transcription preview API", type: :request do
  let(:session) { create_conversation }
  let(:headers) { { "X-Session-Token" => session.client_token } }

  def json
    JSON.parse(response.body)
  end

  it "hands the browser what the fake provider offers for a live caption" do
    AppConfig.current.update!(stt_settings: { "fake_text" => "Bonsoir à tous" })
    session

    post "/api/sessions/#{session.id}/transcription_preview", headers: headers

    expect(response).to have_http_status(:ok)
    expect(json["preview"]).to eq("kind" => "fake", "text" => "Bonsoir à tous")
  end

  it "answers with no preview, and records the error, when the provider cannot stream" do
    allow_any_instance_of(Providers::Stt::Fake).to receive(:live_preview).and_raise(Providers::MissingCredentials, "OPENAI_API_KEY")

    post "/api/sessions/#{session.id}/transcription_preview", headers: headers

    expect(response).to have_http_status(:ok)
    expect(json["preview"]).to be_nil
    expect(session.provider_errors.pluck(:stage)).to eq([ "stt_preview" ])
  end

  it "requires the session token" do
    post "/api/sessions/#{session.id}/transcription_preview"
    expect(response).to have_http_status(:not_found)
  end
end
