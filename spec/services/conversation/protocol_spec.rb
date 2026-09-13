require "rails_helper"

RSpec.describe Conversation::Protocol do
  describe ".parse_client!" do
    it "returns the type and the validated payload" do
      id = SecureRandom.uuid
      expect(described_class.parse_client!("type" => "playback.completed", "payload" => { "turnId" => id.upcase, "spokenMs" => "1200", "junk" => 1 }))
        .to eq([ "playback.completed", { turnId: id, spokenMs: 1200 } ])
    end

    it "rejects unknown types, missing required keys and bad values" do
      expect { described_class.parse_client!("type" => "session.start") }.to raise_error(described_class::InvalidMessage, /unknown message type/)
      expect { described_class.parse_client!("type" => "playback.started", "payload" => {}) }.to raise_error(described_class::InvalidMessage, /turnId is required/)
      expect { described_class.parse_client!("type" => "playback.progress", "payload" => { "turnId" => SecureRandom.uuid, "positionMs" => -1 }) }
        .to raise_error(described_class::InvalidMessage, /positionMs/)
      expect { described_class.parse_client!("type" => "speech.started", "payload" => { "turnId" => "abc" }) }.to raise_error(described_class::InvalidMessage, /UUID/)
      expect { described_class.parse_client!("type" => "turn.request", "protocolVersion" => 2) }.to raise_error(described_class::InvalidMessage, /protocol version/)
      expect { described_class.parse_client!("type" => "turn.request", "payload" => { "x" => "y" * 3000 }) }.to raise_error(described_class::InvalidMessage, /too large/)
    end
  end

  describe ".envelope" do
    it "stamps every server message with protocol, session, event id, version and seq" do
      session = create_conversation
      message = described_class.envelope(session, "state.changed", { status: "listening" })
      expect(message).to include(protocolVersion: 1, type: "state.changed", sessionId: session.id, version: 0, seq: 0, payload: { status: "listening" })
      expect(message[:eventId]).to match(described_class::UUID)
      expect { described_class.envelope(session, "made.up") }.to raise_error(ArgumentError)
    end
  end
end
