require "rails_helper"

RSpec.describe "Audio clips API", type: :request do
  let(:session) { create_conversation }

  before { Conversation::Orchestrator.new(session).start_from_utterance!(text: "Hello") }

  def clip
    session.audio_clips.first
  end

  it "serves a clip to the session that owns it, without caching" do
    get "/api/sessions/#{session.id}/clips/#{clip.id}", headers: { "X-Session-Token" => session.client_token }

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("audio/wav")
    expect(response.headers["Cache-Control"]).to include("no-store")
    expect(response.body.bytesize).to eq(clip.bytes.bytesize)
  end

  it "refuses other sessions and unknown clips" do
    other = create_conversation
    get "/api/sessions/#{other.id}/clips/#{clip.id}", headers: { "X-Session-Token" => other.client_token }
    expect(response).to have_http_status(:not_found)

    get "/api/sessions/#{session.id}/clips/#{clip.id}", headers: { "X-Session-Token" => "wrong" }
    expect(response).to have_http_status(:not_found)
  end

  it "loses its clips when the session is finalized" do
    Conversation::Orchestrator.new(session).finalize!("test")
    expect(session.audio_clips.count).to eq(0)
  end
end
