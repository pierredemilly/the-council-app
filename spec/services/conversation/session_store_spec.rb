require "rails_helper"

RSpec.describe Conversation::SessionStore do
  let(:session) { create_conversation }

  it "assigns monotonic sequence numbers without moving the generation epoch" do
    described_class.with_lock(session.id) { |s| described_class.append_event!(s, kind: "human", text: "one") }
    described_class.with_lock(session.id) { |s| described_class.append_event!(s, kind: "agent", speaker: "Aphra", text: "two") }

    expect(session.reload.events.ordered.pluck(:seq, :text)).to eq([ [ 1, "one" ], [ 2, "two" ] ])
    expect(session.version).to eq(0)
    expect(session.next_seq).to eq(3)
  end

  it "rejects work pinned to a version that has moved on" do
    described_class.with_lock(session.id) { |s| described_class.advance_version!(s) }

    expect {
      described_class.with_lock(session.id, expected_version: 0) { |s| described_class.append_event!(s, kind: "human", text: "late") }
    }.to raise_error(Conversation::StaleVersion)
    expect(session.events.count).to eq(0)
  end

  it "authorizes only with the matching token" do
    expect(described_class.find_authorized(session.id, session.client_token)).to eq(session)
    expect(described_class.find_authorized(session.id, "wrong")).to be_nil
    expect(described_class.find_authorized("not-a-uuid", "x")).to be_nil
    expect { described_class.find_authorized!(session.id, nil) }.to raise_error(Conversation::NotAuthorized)
  end
end
