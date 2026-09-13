require "rails_helper"

RSpec.describe ConversationChannel, type: :channel do
  let(:session) { create_conversation }

  it "rejects subscriptions without a valid token" do
    subscribe(sessionId: session.id, token: "wrong")
    expect(subscription).to be_rejected

    subscribe(sessionId: SecureRandom.uuid, token: session.client_token)
    expect(subscription).to be_rejected
  end

  it "rejects finalized sessions" do
    Conversation::Orchestrator.new(session).finalize!("test")
    subscribe(sessionId: session.id, token: session.client_token)
    expect(subscription).to be_rejected
  end

  it "streams the session and transmits session.ready on subscribe" do
    subscribe(sessionId: session.id, token: session.client_token)

    expect(subscription).to be_confirmed
    expect(subscription).to have_stream_from("conversation:#{session.id}")
    ready = transmissions.last
    expect(ready).to include("type" => "session.ready", "protocolVersion" => 1, "sessionId" => session.id)
    expect(ready["payload"]).to include("status" => "created", "events" => [])
  end

  it "routes validated events to the orchestrator and answers heartbeats" do
    subscribe(sessionId: session.id, token: session.client_token)
    Conversation::Orchestrator.new(session).start_from_utterance!(text: "Hello")
    turn = session.turns.ordered.first

    perform :event, "type" => "playback.started", "payload" => { "turnId" => turn.id }
    expect(session.reload.status).to eq("speaking")

    perform :event, "type" => "client.heartbeat"
    expect(transmissions.last["type"]).to eq("server.heartbeat")
  end

  it "answers malformed messages with a recoverable error instead of raising" do
    subscribe(sessionId: session.id, token: session.client_token)

    perform :event, "type" => "playback.started", "payload" => {}

    expect(transmissions.last).to include("type" => "error.recoverable")
    expect(transmissions.last["payload"]).to include("code" => "invalid_message")
  end
end
