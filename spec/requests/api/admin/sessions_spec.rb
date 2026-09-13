require "rails_helper"

RSpec.describe "Admin sessions API", type: :request do
  let(:admin) { User.create!(email: "admin@example.com", password: "password123") }
  let(:session) { create_conversation }

  before do
    orchestrator = Conversation::Orchestrator.new(session)
    orchestrator.start_from_utterance!(text: "Good evening")
    orchestrator.playback_started!(session.turns.ordered.first.id)
    orchestrator.playback_completed!(session.turns.ordered.first.id)
    ProviderError.record!(session: session, stage: "tts", provider: "fake", error: Providers::Error.new("slow"))
  end

  it "requires a signed-in admin" do
    get "/api/admin/sessions", as: :json
    expect(response).to have_http_status(:unauthorized)
  end

  it "lists recent sessions with their counts" do
    sign_in_as(admin)
    get "/api/admin/sessions", as: :json

    expect(response).to have_http_status(:ok)
    listed = json["sessions"].find { |s| s["id"] == session.id }
    expect(listed).to include("status" => "speaking", "human_turns" => 1, "agent_turns" => 1, "interruptions" => 0, "first_line" => "Good evening")
  end

  it "returns the transcript with latencies and the error log" do
    sign_in_as(admin)
    get "/api/admin/sessions/#{session.id}", as: :json

    expect(response).to have_http_status(:ok)
    expect(json["events"].map { |e| e["kind"] }).to eq(%w[human agent])
    expect(json["events"].first["latency"]).to include("llm_ms")
    expect(json["errors"].first).to include("stage" => "tts", "message" => "slow")
  end

  it "deletes a session and everything attached to it" do
    sign_in_as(admin)
    delete "/api/admin/sessions/#{session.id}", as: :json

    expect(response).to have_http_status(:no_content)
    expect(ConversationSession.exists?(session.id)).to be(false)
    expect(ConversationEvent.count).to eq(0)
  end
end
