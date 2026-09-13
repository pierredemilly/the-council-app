require "rails_helper"

RSpec.describe "Conversation session API", type: :request do
  before { create_conversation }

  def json
    JSON.parse(response.body)
  end

  it "exposes the public configuration without secrets or personality sheets" do
    get "/api/public_config", as: :json

    expect(response).to have_http_status(:ok)
    expect(json["agents"].map { |a| a["name"] }).to eq(%w[Aphra Rosa Claudia])
    expect(json.keys).not_to include("global_system_prompt", "llm_model")
    expect(json["agents"].first.keys).not_to include("personality")
  end

  it "creates a session and returns the token exactly once" do
    post "/api/sessions", params: { clientMode: "kiosk" }, as: :json

    expect(response).to have_http_status(:created)
    session = json["session"]
    expect(session["token"]).to be_present
    expect(session).to include("status" => "created", "clientMode" => "kiosk", "lastSeq" => 0)
    expect(session["config"]["agents"].size).to eq(3)

    get "/api/sessions/#{session['id']}", headers: { "X-Session-Token" => session["token"] }, as: :json
    expect(response).to have_http_status(:ok)
    expect(json["session"]).not_to have_key("token")

    get "/api/sessions/#{session['id']}", headers: { "X-Session-Token" => "wrong" }, as: :json
    expect(response).to have_http_status(:not_found)
  end

  it "falls back to browser mode for unknown client modes" do
    post "/api/sessions", params: { clientMode: "tv" }, as: :json
    expect(json.dig("session", "clientMode")).to eq("browser")
  end

  it "accepts a typed utterance and starts the discussion" do
    post "/api/sessions", as: :json
    session = json["session"]

    post "/api/sessions/#{session['id']}/utterances", params: { text: "Good evening" }, headers: { "X-Session-Token" => session["token"] }, as: :json

    expect(response).to have_http_status(:accepted)
    expect(json["event"]).to include("kind" => "human", "text" => "Good evening", "seq" => 1)
    expect(ConversationSession.find(session["id"]).turns.count).to eq(3)

    post "/api/sessions/#{session['id']}/utterances", params: { text: "" }, headers: { "X-Session-Token" => session["token"] }, as: :json
    expect(response).to have_http_status(:unprocessable_content)
  end

  it "refuses utterances on a finished session" do
    post "/api/sessions", as: :json
    session = json["session"]
    Conversation::Orchestrator.new(ConversationSession.find(session["id"])).finalize!("test")

    post "/api/sessions/#{session['id']}/utterances", params: { text: "Hello?" }, headers: { "X-Session-Token" => session["token"] }, as: :json
    expect(response).to have_http_status(:gone)
  end
end
